defmodule Todo.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: :todo_supervisor)
  end


  def init(_) do
    processes = [
			supervisor(Todo.Database, []),
 			supervisor(Todo.ServerSupervisor, []),
 			worker(Todo.Cache, [])
    ]
    supervise(processes, strategy: :rest_for_one)
  end
end
