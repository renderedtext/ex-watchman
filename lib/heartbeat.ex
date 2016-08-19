defmodule Watchman.Heartbeat do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    spawn fn ->
      send_heartbeat(args[:name], args[:interval])
    end

    {:ok, []}
  end

  defp send_heartbeat(name, interval) do
    Watchman.submit(name, "stayin_alive", :gauge)
    :timer.sleep(interval * 1000)
    send_heartbeat(name, interval)
  end
end
