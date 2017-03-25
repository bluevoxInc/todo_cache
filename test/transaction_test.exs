defmodule TransactionTest do
  use ExUnit.Case, async: false
  require Logger

  setup_all do
    case Application.get_env(:todo, :database_table) do
      nil -> raise "Test database table not specified."
      database_table ->

      File.rm_rf("Mnesia.nonode@nohost")

      # Initializes the mnesia database.
      :mnesia.stop    # First we stop mnesia, so we can create the schema.
      :mnesia.create_schema([node()])
      :mnesia.start
      :mnesia.create_table(database_table, [attributes: [:name, :list, :vclock], disc_only_copies: [node()]])
      :ok = :mnesia.wait_for_tables([database_table], 5000)
    end

    {:ok, apps} = Application.ensure_all_started(:todo)

    on_exit fn ->
      # stop all applications started above
      Enum.each(apps, &Application.stop/1)
      File.rm_rf("Mnesia.nonode@nohost")
    end

    :ok
  end

  #ensure Vclock entry is automatically added with each transaction
  test "vclock transaction" do
    Todo.Database.store({"test_list", {2017, 1, 1}},[%{date: {2017, 1, 1}, title: "band practice"}])
    :timer.sleep(200)
    vclk_1 = Todo.Database.get_vClock({"test_list", {2017, 1, 1}})

    Logger.debug "debugging vclk_1: #{inspect vclk_1}"

    assert(vclk_1 != nil)
  end


  test "vclock ordering" do
    Todo.Database.store({"test_list", {2017, 2, 1}},[%{date: {2017, 2, 1}, title: "basketball game"}])
    :timer.sleep(200)
    vclk_1 = Todo.Database.get_vClock({"test_list", {2017, 2, 1}})
    Todo.Database.store({"test_list", {2017, 2, 1}},
        [%{date: {2017, 2, 1}, title: "band practice"},%{date: {2017, 2, 1}, title: "car repair"}])
    :timer.sleep(200)
    vclk_2 = Todo.Database.get_vClock({"test_list", {2017, 2, 1}})
    
    assert(VectorClock.dominates(vclk_2, vclk_1))
  end

  test "vclock node" do
    Todo.Database.store({"test_list", {2017, 4, 1}},[%{date: {2017, 4, 1}, title: "April Fools"}])
    :timer.sleep(200)
    vclk_1 = Todo.Database.get_vClock({"test_list", {2017, 4, 1}})

    Logger.debug "debugging vclk_1: #{inspect vclk_1}"

    assert(VectorClock.all_nodes(vclk_1) == [node()])
    end

end
