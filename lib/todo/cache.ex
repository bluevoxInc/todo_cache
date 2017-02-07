defmodule Todo.Cache do
  require Logger

  def server_process(todo_list_name) do
    case Swarm.whereis_name(todo_list_name) do
      :undefined -> 
        create_server(todo_list_name)
      pid -> pid
    end
  end

  def create_server(todo_list_name) do
    case Swarm.register_name(todo_list_name, Todo.Server, 
                             :start_link, [todo_list_name]) do
      {:ok, pid} -> pid
      {:error, {:already_registered, pid}} -> pid
    end
  end
end
