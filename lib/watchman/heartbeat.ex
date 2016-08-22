defmodule Watchman.Heartbeat do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    send(self(), {:submit_heartbeat, args[:interval] * 1000})

    {:ok, :ok}
  end

  def handle_info(message = {:submit_heartbeat, interval}, :ok) do
    Watchman.submit("heartbeat", 1, :gauge)

    :timer.send_after(interval, message)

    {:noreply, :ok}
  end
end
