defmodule Todo.DatabaseWorker do
  use GenServer

  def start_link(db_folder, worker_id) do
    IO.puts "Starting database worker #{worker_id}"
    GenServer.start_link(
      __MODULE__, db_folder,
      name: via_tuple(worker_id))
  end

  def store(worker_id, key, data) do
    GenServer.cast(via_tuple(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  def init(db_folder) do
    File.mkdir_p(db_folder)
    {:ok, db_folder}
  end

  def handle_cast({:store, key, data}, db_folder) do
    file_name(db_folder, key)
    |> File.write!(:erlang.term_to_binary(data))

    IO.inspect(self)
    IO.inspect(": storing #{key}")

    {:noreply, db_folder}
  end

  def handle_call({:get, key}, _, db_folder) do
    data = case File.read(file_name(db_folder, key)) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      _ -> nil
    end

    {:reply, data, db_folder}
  end

  def handle_info({:stop}, db_folder) do
    {:stop, :normal, db_folder}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp file_name(db_folder, key), do: "#{db_folder}/#{key}"

  #The :via option expects a module that exports 
  #register_name/2, unregister_name/1, whereis_name/1 and send/2.
  defp via_tuple(worker_id) do
    {:via, Todo.ProcessRegistry, {:database_worker, worker_id}}
  end
end