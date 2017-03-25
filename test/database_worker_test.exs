defmodule DatabaseWorkerTest do
  use ExUnit.Case, async: false

  setup_all do
    {_rtn, worker} = case Application.get_env(:todo, :database_table) do
      nil -> 
        raise "Test database table not specified."
        {:err, nil}
      database_table ->
        File.rm_rf("Mnesia.nonode@nohost")

        :mnesia.stop  
        :mnesia.create_schema([node()])
        :mnesia.start
        :mnesia.create_table(database_table, [attributes: [:name, :list, :vclock], disc_only_copies: [node()]])
        :ok = :mnesia.wait_for_tables([database_table], 5000)

        Todo.DatabaseWorker.start_link(database_table, 1)
    end

    on_exit(fn ->
      send(worker, {:stop})
      File.rm_rf("Mnesia.nonode@nohost")
    end)

    {:ok, worker: worker}
  end

  test "get and store" do
    Todo.DatabaseWorker.store(1, 1, {:some, "data"})
    Todo.DatabaseWorker.store(1, 2, {:another, ["data"]})
    :timer.sleep(200)

    assert({:some, "data"} == Todo.DatabaseWorker.get(1, 1))
    assert({:another, ["data"]} == Todo.DatabaseWorker.get(1, 2))
  end

  test "get_by_name" do
    Todo.DatabaseWorker.store(1,{"test_list", {2017, 1, 1}},[%{date: {2017, 1, 1}, title: "band practice"}])
    Todo.DatabaseWorker.store(1,{"test_list", {2017, 1, 2}},[%{date: {2017, 1, 1}, title: "walk dog"}])
    :timer.sleep(200)

    assert(Todo.DatabaseWorker.get_by_name(1, "test_list") == 
          [%{date: {2017, 1, 1}, title: "band practice"}, %{date: {2017, 1, 1}, title: "walk dog"}])  
  end

end
