defmodule Todo.Reunion.Vclock do
  require Logger

  # Handle node merge based on vector clock fields.
  #
  # This is specific to the Todo list. 
  # The transactions in the local and remote tables are compared by key field.
  # If the keys match, vector clocks are compared. The decsending clock
  # record, in its entirety, is written to both tables.
  #
  # If no relationship is 
  # found, a merge of the data contained in both records is performed. The exception
  # is when cleared data is found in one (or both) records. In this case, if the 
  # cleared entry is older, a new record is written with no data, otherwise the
  # data in the older record is contained in the new record. In all cases, 
  # vector clocks are merged.
  #
  # To activate this function, the M,F,A is specified in the table definition 
  # properties:
  # :mnesia.create_table(Test2, 
  #   [attributes: [:name, :list, :vclock],
  #   disc_only_copies: nodes])
  #
  # :mnesia.write_table_property(Test2, 
  #   {:reunion_compare, {Todo.Reunion.Vclock, :vclock, [:vclock,:list]}}) 
  #

  @key_pos 1 #record tag is the 1st element in the tuple

  def vclock(:init, {tab, :set, attrs, [vclock,data|_]}, rmNode) do
    Logger.info("Starting merge of #{tab} (#{inspect attrs})")
    {:ok, {:set, rmNode, 
                pos(data, tab, attrs), pos(vclock, tab, attrs)}}
  end

  def vclock(:done, state, _rmNode) do
    Logger.info("Merge complete: #{inspect state}")
    :ok
  end

  def vclock(lcl_rcds, rmt_rcds, {:set, rmNode, dp, vp} = state) do
    IO.inspect lcl_rcds
    IO.inspect rmt_rcds
    actions = merge_by_vclock(lcl_rcds, rmt_rcds, rmNode, {dp, vp}, [])
    Logger.info("Writing the following transactions #{inspect actions}")
    {:ok, actions, state}
  end

  defp merge_by_vclock(lcl_rcds, [], _, _, acts) do
    Enum.reduce(lcl_rcds, acts, fn(rcd, acc) -> [{:write_remote, rcd}|acc] end)
  end
  defp merge_by_vclock([], rmt_rcds, _, _, acts) do
    Enum.reduce(rmt_rcds, acts, fn(rcd, acc) -> [{:write_local, rcd}|acc] end)
  end
  defp merge_by_vclock([lcl_rcd|nxt_lcl_rcds], rmt_rcds, rmNode, 
                                                  {_,vclk_pos}=p, acts) do
    
    key = elem(lcl_rcd, @key_pos)
    case List.keytake(rmt_rcds, key, @key_pos) do
      nil ->  
        # local record not in remote, write this to remote. 
        merge_by_vclock(nxt_lcl_rcds, rmt_rcds, rmNode, p, [{:write_remote, lcl_rcd}|acts])
      {^lcl_rcd, nxt_rmt_rcds} ->
        # found identical record in remote, advance with no action.
        merge_by_vclock(nxt_lcl_rcds, nxt_rmt_rcds, rmNode, p, acts)
      {diff_rcd, nxt_rmt_rcds} ->
        # local record and remote content is different:
        case compare_clocks(lcl_rcd, diff_rcd, vclk_pos) do
          :left -> 
            # local record descends remote, overwrite the remote record.
            merge_by_vclock(nxt_lcl_rcds, nxt_rmt_rcds, rmNode, p, 
                            [{:delete_remote, diff_rcd},{:write_remote, lcl_rcd}|acts])
          :right ->
            # remote record descends local, overwrite the local record.
            merge_by_vclock(nxt_lcl_rcds, nxt_rmt_rcds, rmNode, p, 
                            [{:delete_local, lcl_rcd},{:write_remote, diff_rcd}|acts])
          :none -> 
            # records were added to local and remote partitions:
            merged_rcd = merge_records(lcl_rcd, diff_rcd, rmNode, p)
            merge_by_vclock(nxt_lcl_rcds, nxt_rmt_rcds, rmNode, p, 
                            [{:delete_local, lcl_rcd},
                             {:delete_remote, diff_rcd},
                             {:write_local, merged_rcd},
                             {:write_remote, merged_rcd}|acts])
            
        end
    end
  end

  defp compare_clocks(rcd_a, rcd_b, pos) do
    v_clk_a = elem(rcd_a, pos)
    v_clk_b = elem(rcd_b, pos)

    case VectorClock.descends(v_clk_a, v_clk_b) do
      true -> :left
      false -> 
        case VectorClock.descends(v_clk_b, v_clk_a) do
          true -> :right
          false -> :none
      end
    end
  end

  defp merge_records(rcd_a, rcd_b, rmNode, {data_pos, vclk_pos}) do
    vclk_a = elem(rcd_a, vclk_pos)
    vclk_b = elem(rcd_b, vclk_pos)
    vclk_c = VectorClock.merge([vclk_a, vclk_b])
    a_newer_b = VectorClock.get_timestamp(vclk_a, node()) > 
                  VectorClock.get_timestamp(vclk_b, rmNode) 

    data_a = elem(rcd_a, data_pos)
    data_b = elem(rcd_b, data_pos)
    rcd = case {data_a, data_b, a_newer_b} do
      {[], _, true} ->    #only write a cleared record if it is the latest transaction
        put_elem(rcd_a, vclk_pos, vclk_c)
      {[], _, false} ->
        put_elem(rcd_b, vclk_pos, vclk_c)
      {_, [], true} ->
        put_elem(rcd_b, vclk_pos, vclk_c)
      {_, [], false} ->
        put_elem(rcd_a, vclk_pos, vclk_c)
      _ -> 
        data_c = Enum.uniq(data_a ++ data_b)
        put_elem(rcd_a, data_pos, data_c)
    end

    put_elem(rcd, vclk_pos, vclk_c)
  end

  defp pos(attr, tab, attrs) do
    pos(attr, tab, attrs, @key_pos)
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

