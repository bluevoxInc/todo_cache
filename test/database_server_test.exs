defmodule DatabaseServerTest do
  use ExUnit.Case, async: false

  setup do
    :meck.new(Todo.DatabaseWorker, [:no_link])
    :meck.expect(Todo.DatabaseWorker, :start_link, &MockTodo.DatabaseWorker.start/2)
    :meck.expect(Todo.DatabaseWorker, :store, &MockTodo.DatabaseWorker.store/3)
    :meck.expect(Todo.DatabaseWorker, :get, &MockTodo.DatabaseWorker.get/2)

    case Application.get_env(:todo, :database_table) do
      nil -> raise "Test database table not specified."
      database_table ->
      {:ok, _} = Todo.DatabaseWorker.start_link(database_table, 1)
      {:ok, _} = Todo.DatabaseWorker.start_link(database_table, 2)
    end

    on_exit(fn ->
      :meck.unload(Todo.DatabaseWorker)
    end)
  end

  test "pooling" do
    # NOTE: return values come from MockTodo.DatabaseWorker, 
    # which returns self for store and get calls.
    assert(Todo.Database.store(1, :a) == Todo.Database.store(1, :a))
    assert(Todo.Database.get(1) == Todo.Database.store(1, :a))
    assert(Todo.Database.store(2, :a) != Todo.Database.store(1, :a))
  end
end

defmodule MockTodo.DatabaseWorker do
  use GenServer

  def start(db_table, worker_id) do
    GenServer.start_link(__MODULE__, db_table, name: worker_alias(worker_id))
  end

  def store(worker_id, key, data) do
    GenServer.call(worker_alias(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    GenServer.call(worker_alias(worker_id), {:get, key})
  end

  defp worker_alias(worker_id) do
    :"database_worker_#{worker_id}"
  end


  def init(state) do
    {:ok, state}
  end

  def handle_call({:store, _, _}, _, state) do
    {:reply, self(), state}
  end

  def handle_call({:get, _}, _, state) do
    {:reply, self(), state}
  end

  # Needed for test purposes
  def handle_info({:stop}, state), do: {:stop, :normal, state}
  def handle_info(_, state), do: {:noreply, state}
end
