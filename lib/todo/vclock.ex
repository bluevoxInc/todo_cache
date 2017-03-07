defmodule Todo.Vclock do

  # Function increments the v_clock entry and writes the record to
  # the given table. If this is a new record a fresh vclock is created
  # and incremented.
  # Of the form:
  #
  #action = fn() -> apply(Todo.Vclock, :write, [{DB_NAME, key, data}]) end
  #Wrapped in a transaction when called from the Todo.DatabaseWorker 
  #module
  #
  def write_rec({tab, key, data}) do
    v_inc = case :mnesia.wread({tab, key}) do
      [{_, _, _, v_clock}] ->
        :unsplit_vclock.increment(node(), v_clock)
      [] -> 
        :unsplit_vclock.increment(node(), :unsplit_vclock.fresh())
    end

    :mnesia.write({tab, key, data, v_inc})
      
  end

  #Set of custom functions called from the unsplit application to
  # handle node merge based on vector clock fields.
  #
  #The M,F,A is designated in the table definition user_properties
  # as such:
  # :mnesia.create_table(Test, 
  #   [attributes: [:name, :list, :vclock],
  #   user_properties: [unsplit_method: 
  #   {Todo.Vclock, :vclock, [:vclock]}], 
  #   disc_only_copies: nodes])

  def vclock(:init, [tab, attrs, attr]) do
    case Enum.member?(attrs, attr) do
      false ->
        Todo.Logger.error("Cannot merge table #{tab}, 
          missing attribute #{inspect attr}")
        :stop
      true ->
        Todo.Logger.info("Starting merge of #{tab} (#{inspect attrs})")
        {:ok, {tab, pos(attr, tab, attrs)}}
    end
  end

  def vclock(:done, _) do
    :stop
  end

  def vclock(objs, {tbl, position} = state) do
    IO.inspect objs
    comp = fn(v_clk_a, v_clk_b) ->
      case :unsplit_vclock.descends(v_clk_a, v_clk_b) do
        true -> :left
        false -> 
          case :unsplit_vclock.descends(v_clk_b, v_clk_a) do
            true -> :right
            false -> :none
          end
      end
    end

    actions = List.flatten Enum.map(objs, 
                fn(obj) -> compare(obj, tbl, position, comp) end)

    {:ok, actions, :all_keys, state}
  end

  defp compare({a1, b1} = obj, _tab, p, comp) do
    Todo.Logger.info("compare #{inspect a1}")
    Todo.Logger.info("with #{inspect b1}")
    rtn_val = case obj do
      {a, []} -> {:write, a}
      {[], b} -> {:write, b}
      {[rcd_a], [rcd_b]} ->
        v_clk_a = elem(rcd_a, p)
        v_clk_b = elem(rcd_b, p)
        case comp.(v_clk_a, v_clk_b) do
          :left -> 
            Todo.Logger.info("#{inspect v_clk_a} descends #{inspect v_clk_b}, writing #{inspect v_clk_a}")
            {:write, [rcd_a]}
          :right ->
            Todo.Logger.info("#{inspect v_clk_b} descends #{inspect v_clk_a}, writing #{inspect v_clk_b}")
            {:write, [rcd_b]}
          :none -> 
            Todo.Logger.info("no relationship found between #{inspect v_clk_a} and #{inspect v_clk_b} ... punt")
            [] 
        end
    end
    rtn_val
  end

  #defp inc_vclock([rcd], position) do
    #  v_clock = elem(rcd, position)
    #new_v_clock = :unsplit_vclock.increment(node(), v_clock)
    #new_rcd = put_elem(rcd, position, new_v_clock)
    #[new_rcd]
    #end

  defp pos(attr, tab, attrs) do
    pos(attr, tab, attrs, 1) #record tag is the 1st element in the tuple
  end
  defp pos(attr, _, [attr|_], p) do
    p
  end
  defp pos(attr, tab, [_|t], p) do
    pos(attr, tab, t, (p + 1)) 
  end
  defp pos(attr, tab, [], _) do
    :mnesia.abort({:missing_attribute, tab, attr})
  end
end

