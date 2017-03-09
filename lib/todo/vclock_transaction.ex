defmodule Todo.Vclock.Transaction do

  # Function increments the v_clock entry and writes the record to
  # the given table. If this is a new record a fresh vclock is created
  # and incremented.
  # Of the form:
  #
  # action = fn() -> apply(Todo.Vclock, :write, [{DB_NAME, key, data}]) end
  # This is wrapped in a transaction when called from the Todo.DatabaseWorker 
  # module.
  #
  alias VectorClock.Dot

  def write_rec({tab, key, data}) do
    v_inc = case :mnesia.wread({tab, key}) do
      [{_, _, _, v_clock}] ->
        VectorClock.increment(v_clock, node())
      [] -> 
        VectorClock.fresh(node(), 1)
    end

    :mnesia.write({tab, key, data, v_inc})
      
  end
end
