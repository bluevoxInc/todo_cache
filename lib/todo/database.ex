defmodule Todo.Database do
  @pool_size 3

  def start_link do
    Todo.PoolSupervisor.start_link(@pool_size)
  end

  def store(key, data) do
    key
    |> choose_worker
    |> Todo.DatabaseWorker.store(key, data)
  end

  def get(key) do
    key
    |> choose_worker
    |> Todo.DatabaseWorker.get(key)
  end

  def get_by_name(todo_list_name) do
    {todo_list_name, {2017, 2, 13}}       # arbitrary date just to get a worker
    |> choose_worker
    |> Todo.DatabaseWorker.get_by_name(todo_list_name)
  end

  defp choose_worker(key) do
    :erlang.phash2(key, @pool_size) + 1
  end
end
