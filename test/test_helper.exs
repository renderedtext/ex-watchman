defmodule TestUDPServer do
  use GenServer

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  def init([port: port]) do
    {:ok, _} = :gen_udp.open(port, [:binary, active: true])

    {:ok, []}
  end

  def last_message do
    GenServer.call(__MODULE__, :last_message)
  end

  def handle_info({_udp, _socket, _host, _port, package}, messages) do
    {:noreply, [package| messages]}
  end

  def handle_call(:last_message, _from, messages) do
    {:reply, hd(messages), messages}
  end
end

ExUnit.start()
