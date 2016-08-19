defmodule Watchman.Heartbeat do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    spawn fn ->
      send_heartbeat(args[:interval])
    end

    {:ok, []}
  end

  defp send_heartbeat(interval) do
    Watchman.submit("heartbeat", 1, :gauge)
    :timer.sleep(interval * 1000)
    send_heartbeat(interval)
  end
end
