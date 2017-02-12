defmodule Todo.Server do
  use GenServer

  @timeout 1*60*60*1000

  def start_link(list_name) do
    Todo.Logger.info("Starting to-do server for #{list_name}")
    GenServer.start_link(__MODULE__, [list_name])
  end

  def add_entry(todo_server, new_entry) do
    GenServer.call(todo_server, {:add_entry, new_entry})
  end

  def delete_entry_date(todo_server, date) do
    GenServer.call(todo_server, {:delete_entry_date, date})
  end

  def entries(todo_server, date) do
    GenServer.call(todo_server, {:entries, date})
  end

  def what_node_name(name) do
    case Swarm.whereis_name(name) do
      :undefined -> :undefined
      pid -> GenServer.call(pid, :what_node_name)
    end
  end

  def init([name]) do
    # Time out this process after _ hours
    # I don't want it to run forever.
    timer = Process.send_after(self(), :name_server_timeout, @timeout)

    # Don't restore from the database immediately. Instead lazily
    # fetch entries for the required date on first request.
    {:ok, {name, timer, Todo.List.new}}
  end

  def handle_call({:add_entry, new_entry}, _, {name, timer, todo_list}) do
    new_list = 
      todo_list
      |> initialize_entries(name, new_entry.date)
      |> Todo.List.add_entry(new_entry)

    # Store just the entries of the subject date. This reduces the 
    # incremental amount of data that needs to be stored. This could
    # be made more fine-grained but at the expense of more complex 
    # queries.
    Todo.Database.store(
      {name, new_entry.date},   #The key is now more complex
      Todo.List.entries(new_list, new_entry.date)
    )
    GenServer.cast(__MODULE__, :reset_timer)
    {:reply, :ok, {name, timer, new_list}}
  end
   
  def handle_call({:delete_entry_date, date}, _, {name, timer, todo_list}) do
    Todo.Database.delete({name, date})

    # It's conceivable that this delete request could be waiting in a database_worker 
    # queue when a subsequent write request for the same date is being processed. 
    # The write process will check the cache for the subject date. 
    # The date entry will not be found so a request will be made to the database to refresh the cache. 
    # But the data, slated for deletion may not have been deleted in the DB yet because the request
    # is waiting its turn in the queue. So the cache could be refreshed with transient data 
    # that should be gone. 
    # To get around this just reset the cache entry for this date 
    # to an empty list. This will prevent the cache from subsequently refreshing 
    # with stale date and the write request will be adding data to a clean list.
    new_list = Todo.List.set_entries(todo_list, date, [])

    GenServer.cast(__MODULE__, :reset_timer)
    {:reply, :ok, {name, timer, new_list}}
  end

  def handle_call({:entries, date}, _, {name, timer, todo_list}) do
    new_list = initialize_entries(todo_list, name, date)
    GenServer.cast(__MODULE__, :reset_timer)
    {:reply, Todo.List.entries(new_list, date), {name, timer, new_list}}
  end

  # called when a handoff has been initiated due to changes
  # in cluster topology, valid response values are:
  # 
  # - `:restart`, to simply restart the process on the new node
  # - `{:resume, state}`, to hand off some state to the new process
  # - `:ignore`, to leave the process running on it's current node
  # 
  #def handle_call({:swarm, :begin_handoff}, _from, {name, timer, todo_list}) do
    #  Logger.info "begin handoff name: #{name}"
    #IO.inspect todo_list
    #{:reply, {:resume, todo_list}, {name, timer, todo_list}}
    #end
  def handle_call({:swarm, :begin_handoff}, _from, {name, timer, todo_list}) do
    Todo.Logger.debug "begin handoff name: #{name}"
    {:reply, :restart, {name, timer, todo_list}}
  end

  # what node is this named process running on?
  def handle_call(:what_node_name, _from, state) do
    {:reply, node(), state}
  end

  # called after the process has been restarted on it's new node,
  #and the old process's state is being handed off. This is only
  # sent if the return to `begin_handoff` was `{:resume, state}`.
  # **NOTE**: This is called *after* the process is successfully started,
  # so make sure to design your processes around this caveat if you
  # wish to hand off state like this.
  def handle_cast({:swarm, :end_handoff, todo_list_handoff}, {name, timer, _}) do
    Todo.Logger.debug "end handoff name: #{name}"
    {:noreply, {name, timer, todo_list_handoff}}
  end
  # called when a network split is healed and the local process
  # should continue running, but a duplicate process on the other
  # side of the split is handing off it's state to us. You can choose
  # to ignore the handoff state, or apply your own conflict resolution
  # strategy
  #
  # In this case I depend on mnesia to merge,
  # so clear the cash and let it reload on the next request.
  def handle_cast({:swarm, :resolve_conflict, _todo_list}, {name, timer, _}) do
    Todo.Logger.debug "healing a network split --#{name}"
    {:noreply, {name, timer, Todo.List.new}}
  end

  def handle_cast(:reset_timer, {name, timer, todo_list}) do
    :timer.cancel(timer)
    timer = Process.send_after(self(), :name_server_timeout, @timeout)
    {:noreply, {name, timer, todo_list}}
  end

  # needed for test purposes
  def handle_info({:stop}, state) do
    {:stop, :normal, state}
  end
  # This message is sent when this process should die
  # because it's being moved, use this as an opportunity
  # to clean up.
  def handle_info({:swarm, :die}, {name, timer, todo_list}) do
    Todo.Logger.debug "process for #{name} shut down because it is being moved"
    {:stop, :shutdown, {name, timer, todo_list}}
  end
  def handle_info(:name_server_timeout, {name, timer, todo_list}) do
    Todo.Logger.debug "#{name} has timed out"
    {:stop, :timeout, {name, timer, todo_list}}
  end
  def handle_info(_, state), do: {:noreply, state}

  # Initilize entries for the given date. Use cached data if available,
  # otherwise load from the database. If no data available return an
  # empty list
  defp initialize_entries(todo_list, name, date) do
    case Todo.List.entries(todo_list, date) do
      nil ->
        entries = Todo.Database.get({name, date}) || []
        Todo.List.set_entries(todo_list, date, entries)

      _found -> todo_list
    end
  end

end

