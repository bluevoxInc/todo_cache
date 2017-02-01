defmodule Todo.Cache do

  def server_process(todo_list_name) do
    case Todo.Server.whereis(todo_list_name) do
      :undefined -> 
        createServer(todo_list_name)
      pid -> pid
    end
  end

  def createServer(todo_list_name) do
    case Todo.ServerSupervisor.start_child(todo_list_name) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

end
