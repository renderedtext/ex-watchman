defmodule Watchman.System do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    # seconds
    interval = args[:interval] || 60

    send(self(), {:submit, interval * 1000})

    {:ok, :ok}
  end

  def handle_info(message = {:submit, interval}, :ok) do
    submit_memory()

    :timer.send_after(interval, message)

    {:noreply, :ok}
  end

  def submit_memory() do
    Watchman.submit("system.memory.total", :erlang.memory() |> Keyword.get(:total))
    Watchman.submit("system.memory.processes", :erlang.memory() |> Keyword.get(:processes))

    Watchman.submit(
      "system.memory.processes_used",
      :erlang.memory() |> Keyword.get(:processes_used)
    )

    Watchman.submit("system.memory.atom", :erlang.memory() |> Keyword.get(:atom))
    Watchman.submit("system.memory.atom_used", :erlang.memory() |> Keyword.get(:atom_used))
    Watchman.submit("system.memory.binary", :erlang.memory() |> Keyword.get(:binary))
    Watchman.submit("system.memory.code", :erlang.memory() |> Keyword.get(:code))
    Watchman.submit("system.memory.ets", :erlang.memory() |> Keyword.get(:ets))
    Watchman.submit("system.process.count", Process.list() |> Enum.count())
  end
end
