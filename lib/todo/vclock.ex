defmodule Todo.Vclock do

  #action = fn() -> apply(Todo.Vclock, :write, [{DB_NAME, key, data}]) end
  #
  def write({tab, key, data}) do
    v_inc = case :mnesia.wread({tab, key}) do
      [{_, _, _, vclock}] ->
        :unsplit_vclock.increment(node(), vclock)
      [] -> 
        :unsplit_vclock.increment(node(), :unsplit_vclock.fresh())
    end

    :mnesia.write({tab, key, data, v_inc})
      
  end
end

