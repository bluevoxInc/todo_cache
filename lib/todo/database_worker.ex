defmodule Todo.DatabaseWorker do
  use GenServer
  require Logger

  def start_link(db_folder, worker_id) do
    Logger.info "Starting database worker #{worker_id}"
    GenServer.start_link(
      __MODULE__, db_folder,
      name: via_tuple(worker_id))
  end

  def store(worker_id, key, data) do
    Logger.info "DatabaseWorker #{worker_id} writing #{key}"
    GenServer.cast(via_tuple(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    Logger.info "DatabaseWorker #{worker_id} reading #{key}"
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  def init(db_folder) do
    File.mkdir_p(db_folder)
    {:ok, db_folder}
  end

  def handle_cast({:store, key, data}, db_folder) do
    file_name(db_folder, key)

    # Note the !. We need to fast fail and 'Let it crash' if we
    # cannot write to file. No sense in continuing if cannot persist data.
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, db_folder}
  end

  def handle_call({:get, key}, _, db_folder) do
    data = case File.read(file_name(db_folder, key)) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      {:error, :enoent} -> nil # if file doesn't exist return nil
      # any other file read errors like insufficient permissions, 
      # 'Let it crash'.
    end

    {:reply, data, db_folder}
  end

  # Needed for testing purposes
  def handle_info(:stop, state), do: {:stop, :normal, state}
  def handle_info(_, state), do: {:noreply, state}

  defp file_name(db_folder, key), do: "#{db_folder}/#{key}"

  #The :via option expects a module that exports 
  #register_name/2, unregister_name/1, whereis_name/1 and send/2.
  defp via_tuple(worker_id) do
    {:via, :gproc, {:n, :l, {:database_worker, worker_id}}}
  end
end
