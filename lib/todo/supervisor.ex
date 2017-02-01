defmodule Todo.Supervisor do
  use Supervisor

  def start_link do
    case Application.get_env(:todo, :persist) do
      nil -> raise "Persist directory not specified"
      persist_dir ->
        Supervisor.start_link(__MODULE__, persist_dir, name: :todo_supervisor)
    end
  end

  def init(persist_dir) do
    processes = [
			supervisor(Todo.Database, [persist_dir]),
 			supervisor(Todo.ServerSupervisor, [])
    ]
    supervise(processes, strategy: :one_for_one)
  end
end
