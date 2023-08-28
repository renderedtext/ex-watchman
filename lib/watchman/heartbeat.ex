defmodule Watchman.Heartbeat do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    send(self(), {:submit_heartbeat, args[:interval] * 1000, now()})

    {:ok, :ok}
  end

  def handle_info(message = {:submit_heartbeat, interval, start_time}, :ok) do
    Watchman.submit("heartbeat", now - start_time, :gauge)

    :timer.send_after(interval, message)

    {:noreply, :ok}
  end

  defp now do
    :calendar.datetime_to_gregorian_seconds(:calendar.universal_time)
  end
end
