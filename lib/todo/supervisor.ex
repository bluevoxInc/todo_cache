defmodule Todo.Supervisor do
  use Supervisor

  def start_link do
    case Application.get_env(:todo, :database_table) do
      nil -> raise "Todo database table not specified."
      database_table ->
        Supervisor.start_link(__MODULE__, database_table, name: :todo_supervisor)
    end
  end


  def init(database_table) do
    processes = [
			supervisor(Todo.Database, [database_table]),
 			supervisor(Todo.ServerSupervisor, [])
    ]
    supervise(processes, strategy: :rest_for_one)
  end
end
