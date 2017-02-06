defmodule Todo.DatabaseWorker do
  use GenServer
  require Logger

  def start_link(worker_id) do
    Logger.info "Starting database worker #{worker_id}"

    GenServer.start_link(
      __MODULE__, nil,
      name: via_tuple(worker_id))
  end

  def store(worker_id, key, data) do
    GenServer.call(via_tuple(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  #The :via option expects a module that exports 
  #register_name/2, unregister_name/1, whereis_name/1 and send/2.
  defp via_tuple(worker_id) do
    {:via, :gproc, {:n, :l, {:database_worker, worker_id}}}
  end

  def init(_) do
    # Rather than handling one request at a time, the worker attempts
    # to adapt to increased load by batching requests.
    #
    # This done by internally spawning another process to perform storage.
    # While the worker is doing its job, all incomming requests will be 
    # queued. When the storage process finishes, a new storage process
    # will be spawned and the queue will be stored to the DB in a single 
    # pass. (The caveat here is if the storage process or the database
    # worker instance should crash, the requests in the queue -- an 
    # indeterminate number -- would be lost. So this is a performant solution
    # but one at the expense of data integrity.)
    #
    # This is beneficial, because storing N items in a single pass is
    # much faster than storing one request at a time.
    #
    # Another feature is that multiple updates in the same queue can 
    # be avoided. If a request arrives for an item already in the queue,
    # the older request can be overwritten and only the most recent 
    # request will actually be written.
    #
    {
      :ok,
      %{
        store_job: nil,           #PID of the storing job
        store_queue: Map.new      #Queue of incoming items to store
      }
    }
  end

  def handle_call({:store, key, data}, from, state) do
    new_state =
      state
      |> queue_request(from, key, data)
      |> maybe_store

    # Reply will be handled by the storing job
    {:noreply, new_state}
  end

  def handle_call({:get, key}, _, state) do
    # Always read from the database. Looking up data in the queue should
    # not be done because the data is not actually stored and might not
    # actually end up in the database.
#IO.inspect key
    read_result = :mnesia.transaction(fn -> 
      :mnesia.read({:todo_lists, key}) end)

    data = case read_result do
      {:atomic, [{:todo_lists, ^key, list}]} -> list
      _ -> nil
    end

    {:reply, data, state}
  end

  def handle_info({:DOWN, _, :process, pid, _}, %{store_job: store_job} = state) 
    when pid == store_job
  do
    # Clear the store job (PID) and immediately invoke maybe_store to
    # start another store job, provided there is something in the queue.
    {:noreply, maybe_store(%{state | store_job: nil})}
  end

  # Needed for testing purposes
  def handle_info(:stop, state), do: {:stop, :normal, state}

  def handle_info(_, state), do: {:noreply, state}

  defp queue_request(state, from, key, data) do
    %{state | store_queue: Map.put(state.store_queue, key, {from, data})}
  end

  defp maybe_store(%{store_job: nil} = state) do
    # store_job = nil indicates no storage process is running so
    # it is safe to start a new process.
     
    if map_size(state.store_queue) > 0 do
      start_store_job(state)
    else
      state   # Queue is empty, no job to run right now
    end
  end

  # store_job is running, continue adding to the queue
  defp maybe_store(state), do: state

  defp start_store_job(state) do
    # spawn_link the job. No need for a supervisor. If the store_job
    # crashes the database_worker will do so as well, and vice-versa.
    store_job = spawn_link(fn -> do_write(state.store_queue) end)

    #Set up a monitor so a DOWN message will be receives upon completion
    Process.monitor(store_job)

    %{state |
      store_queue: Map.new,       #reset the queue
      store_job: store_job        #PID of running job
    }
  end

  defp do_write(store_queue) do
    # Store the data
    {:atomic, :ok} = :mnesia.transaction(fn ->
      for {key, {_, data}} <- store_queue do
        :ok = :mnesia.write({:todo_lists, key, data})
      end
      :ok
    end)

    #Reply to clients:
    for {_, {from, _}} <- store_queue do
#IO.inspect key
#IO.inspect data
      GenServer.reply(from, :ok)
    end
  end

end
