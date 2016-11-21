defmodule Todo.Server do
  use GenServer

  def start do
    GenServer.start(Todo.Server, nil)
  end

  def add_entry(todo_server, new_entry) do
    GenServer.cast(todo_server, {:add_entry, new_entry})
  end

  def delete_entry(todo_server, id) do
    GenServer.cast(todo_server, {:delete_entry, id})
  end

  def entries(todo_server, date) do
    GenServer.call(todo_server, {:entries, date})
  end

  def all_entries(todo_server) do
    GenServer.call(todo_server, {:all_entries})
  end

  def init(_) do
    {:ok, Todo.List.new}
  end

  def handle_cast({:add_entry, new_entry}, todo_list) do
    new_state = Todo.List.add_entry(todo_list, new_entry)
    {:noreply, new_state}
  end

  def handle_cast({:delete_entry, id}, todo_list) do
    new_state = Todo.List.delete_entry(todo_list, id)
    {:noreply, new_state}
  end

  def handle_call({:entries, date}, _, todo_list) do
    {
      :reply,
      Todo.List.entries(todo_list, date),
      todo_list
    }
  end

  def handle_call({:all_entries}, _, todo_list) do
    {:reply, Todo.List.all_entries(todo_list), todo_list}
  end
end

