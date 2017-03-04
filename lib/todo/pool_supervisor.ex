defmodule Todo.PoolSupervisor do
  use Supervisor

  def start_link(db_table, pool_size) do
    Supervisor.start_link(__MODULE__, {db_table, pool_size}, 
      name: :pool_supervisor)
  end

  def init({db_table, pool_size}) do
    processes = for worker_id <- 1..pool_size do
      worker(
        Todo.DatabaseWorker, [db_table, worker_id],
          id: {:database_worker, worker_id}
      )
    end

    supervise(processes, strategy: :one_for_one)
  end
end
