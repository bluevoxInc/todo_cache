defmodule Todo.Server do
  use GenServer
  require Logger

  def start_link(list_name) do
    Logger.info("Starting to-do server for #{list_name}")
    GenServer.start_link(
      Todo.Server, 
      list_name, 
      name: via_tuple(list_name)
    )
  end

  def add_entry(todo_server, new_entry) do
    GenServer.call(todo_server, {:add_entry, new_entry})
  end

  def entries(todo_server, date) do
    GenServer.call(todo_server, {:entries, date})
  end

  def whereis(name) do
    :gproc.whereis_name({:n, :l, {:todo_server, name}})
  end

  defp via_tuple(name) do
    {:via, :gproc, {:n, :l, {:todo_server, name}}}
  end

  def init(name) do
    # Don't restore from the database immediately. Instead lazily
    # fetch entries for the required date on first request.
    {:ok, {name, Todo.List.new}}
  end

  def handle_call({:add_entry, new_entry}, _, {name, todo_list}) do
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

    {:reply, :ok, {name, new_list}}
  end

  def handle_call({:entries, date}, _, {name, todo_list}) do
    new_list = initialize_entries(todo_list, name, date)
    {:reply, Todo.List.entries(new_list, date), {name, new_list}}
  end

  # needed for test purposes
  def handle_info({:stop}, state) do
    {:stop, :normal, state}
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

