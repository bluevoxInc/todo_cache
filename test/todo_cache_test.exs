defmodule TodoCacheTest do
  use ExUnit.Case, async: false

  setup do
    :meck.new(Todo.Database, [:no_link])
    :meck.expect(Todo.Database, :start_link, fn(_) -> nil end)
    :meck.expect(Todo.Database, :get, fn(_) -> nil end)
    :meck.expect(Todo.Database, :store, fn(_, _) -> :ok end)

    {:ok, cache} = Todo.Cache.start_link

    on_exit(fn ->
      :meck.unload(Todo.Database) 
      send(cache, {:stop})
    end)

  end

  test "server_process" do
    bobs_list = Todo.Cache.server_process("bobs_list")
    alices_list = Todo.Cache.server_process("alices_list")

    assert(bobs_list != alices_list)
    assert(bobs_list == Todo.Cache.server_process("bobs_list"))

  end
end
