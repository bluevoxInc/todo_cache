defmodule TodoCacheTest do
  use ExUnit.Case, async: false

  setup do
    :meck.new(Todo.Database, [:no_link])
    :meck.expect(Todo.Database, :start, fn(_) -> nil end)
    :meck.expect(Todo.Database, :get, fn(_) -> nil end)
    :meck.expect(Todo.Database, :store, fn(_, _) -> :ok end)

    {:ok, cache} = Todo.Cache.start

    on_exit(fn ->
      :meck.unload(Todo.Database) 
      send(cache, {:stop})
    end)

    {:ok, todo_cache: cache}
  end

  test "server_process", context do
    bobs_list = Todo.Cache.server_process(context[:todo_cache], "bobs_list")
    alices_list = Todo.Cache.server_process(context[:todo_cache], "alices_list")

    assert(bobs_list != alices_list)
    assert(bobs_list == Todo.Cache.server_process(context[:todo_cache], "bobs_list"))

  end
end
