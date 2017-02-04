defmodule Todo.Cluster do
  use GenServer
  require Logger

  def start_link() do
    Logger.info("Starting Todo.Cluster")
    GenServer.start_link(__MODULE__, nil, name: :todo_cluster)
  end

  def init(_) do
    # monitor peers joining/leaving the cluster:
    :net_kernel.monitor_nodes(true)    
    {:ok, %{node_ct: 1}}
  end

  def handle_info({:nodeup, member}, %{node_ct: count} = state) do
    count = count + 1
    Logger.info("#{member} has connected, #{count} nodes")
    {:noreply, %{state | node_ct: count}}
  end
  def handle_info({:nodedown, member}, %{node_ct: count} = state) do
    count = count - 1
    Logger.info("#{member} has disconnected, #{count} nodes")
    {:noreply, %{state | node_ct: count}}
  end
  # overriding handle_info above requires that a default 
  # handle_info be defined as well
  def handle_info(_, state), do: {:noreply, state}

end
