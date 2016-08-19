defmodule Watchman.Heartbeat do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    :timer.send_after(args[:interval] * 1000, args[:interval])

    {:ok, []}
  end

  def handle_info(package, state) do
    Watchman.submit("heartbeat", 1, :gauge)
    :timer.send_after(package * 1000, "send")
    {:noreply, state}
  end
end
