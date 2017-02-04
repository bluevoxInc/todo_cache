defmodule Todo.Server do
  use GenServer
  require Logger

  def start_link(list_name) do
    Logger.info("Starting to-do server for #{list_name}")
    GenServer.start_link(
      Todo.Server, 
      list_name, 
      name: {:global, {:todo_server, list_name}}
    )
  end

  def whereis(list_name) do
    :global.whereis_name({:todo_server, list_name})
  end

  def add_entry(todo_server, new_entry) do
    GenServer.cast(todo_server, {:add_entry, new_entry})
  end

  def delete_entry(todo_server, id) do
    GenServer.cast(todo_server, {:delete_entry, id})
  end

  def update_entry(todo_server, entry) do
    GenServer.cast(todo_server, {:update_entry, entry})
  end

  def entries(todo_server, date) do
    GenServer.call(todo_server, {:entries, date})
  end

  def all_entries(todo_server) do
    GenServer.call(todo_server, {:all_entries})
  end

  def init(name) do
    send(self(), :real_init) #send first msg to handle data load
    {:ok, {name, nil}}
  end

  def handle_cast({:add_entry, new_entry}, {name, todo_list}) do
    new_state = Todo.List.add_entry(todo_list, new_entry)
    Todo.Database.store(name, new_state)
    {:noreply, {name, new_state}}
  end

  def handle_cast({:delete_entry, id}, {name, todo_list}) do
    new_state = Todo.List.delete_entry(todo_list, id)
    Todo.Database.store(name, new_state)
    {:noreply, {name, new_state}}
  end

  def handle_cast({:update_entry, entry}, {name, todo_list}) do
    new_state = Todo.List.update_entry(todo_list, entry)
    Todo.Database.store(name, new_state)
    {:noreply, {name, new_state}}
  end

  def handle_call({:entries, date}, _, {name, todo_list}) do
    {
      :reply,
      Todo.List.entries(todo_list, date),
      {name, todo_list}
    }
  end

  def handle_call({:all_entries}, _, {name, todo_list}) do
    {:reply, Todo.List.all_entries(todo_list), {name, todo_list}}
  end

  # handle the data load here so as not to block GenServer init/start
  #-- this is not necessary for this app, just to try out the technique
  def handle_info(:real_init, {name, _}) do
    {:noreply, {name, Todo.Database.get(name) || Todo.List.new}}
  end
  # needed for test purposes
  def handle_info({:stop}, state) do
    {:stop, :normal, state}
  end
  # overriding handle_info above requires that a default 
  # handle_info be defined as well
  def handle_info(_, state), do: {:noreply, state}


end

