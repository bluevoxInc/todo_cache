defmodule Todo.Database do
  use GenServer

  def start(db_folder) do
    GenServer.start(__MODULE__, db_folder, name: :database_server)
  end

  def store(key, data) do
    worker_pid = get_worker(key)
    Todo.DatabaseWorker.store(worker_pid, key, data)
  end

  def get(key) do
    worker_pid = get_worker(key) 
    Todo.DatabaseWorker.get(worker_pid, key)
  end

  def get_worker(key) do
    GenServer.call(:database_server, {:get_worker, key})
  end

  def init(db_folder) do
    File.mkdir_p(db_folder)

    worker_pool = 
      0..2 
      |> Enum.reduce(HashDict.new, 
        &HashDict.put(&2, &1, 
        (fn -> 
          {:ok, pid} = Todo.DatabaseWorker.start(db_folder)
          pid
        end).()))

    IO.inspect worker_pool

    {:ok, worker_pool}
  end

  def handle_call({:get_worker, key}, _, worker_pool) do
    worker_pid = HashDict.get(worker_pool, :erlang.phash2(key, 3))

    {:reply, worker_pid, worker_pool}
  end

  def handle_info({:stop}, worker_pool) do
    HashDict.to_list(worker_pool)
    |> Enum.each(fn {_k, {:ok, pid}} -> send(pid, {:stop}) end)

    {:stop, :normal, worker_pool}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
