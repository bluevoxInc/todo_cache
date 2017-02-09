defmodule Todo.Logger do
  require Logger

  @spec debug(String.t) :: :ok
  def debug(message), do: Logger.debug("[todo on #{Node.self}] #{message}")

  @spec warn(String.t) :: :ok
  def warn(message), do: Logger.warn("[todo on #{Node.self}] #{message}")

  @spec info(String.t) :: :ok
  def info(message), do: Logger.info("[todo on #{Node.self}] #{message}")

  @spec error(String.t) :: :ok
  def error(message), do: Logger.error("[todo on #{Node.self}] #{message}")

end
