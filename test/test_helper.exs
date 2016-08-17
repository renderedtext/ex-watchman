defmodule TestUDPServer do
  use GenServer

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  def init([port: port]) do
    {:ok, _} = :gen_udp.open(port, [:binary, active: true])

    {:ok, nil}
  end

  def last_message do
    GenServer.call(__MODULE__, :last_message)
  end

  def handle_info({udp, socket, host, port, package}, last_message) do
    {:noreply, package}
  end

  def handle_call(:last_message, _from, last_message) do
    {:reply, last_message, last_message}
  end
end

ExUnit.start()
