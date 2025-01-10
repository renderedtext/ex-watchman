defmodule TestUDPServer do
  use GenServer

  @test_port 8125

  def start_link() do
    pid = Process.whereis(__MODULE__)

    if pid do
      {:ok, pid}
    else
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end
  end

  def wait_for_clean_message_box do
    pid = Process.whereis(__MODULE__)
    {:message_queue_len, len} = Process.info(pid, :message_queue_len)

    if len > 0 do
      :timer.sleep(100)
      wait_for_clean_message_box()
    end

    :ok
  end

  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  def init([]) do
    {:ok, _} = :gen_udp.open(@test_port, [:binary, active: true])

    {:ok, []}
  end

  def last_message do
    wait_for_clean_message_box()

    GenServer.call(__MODULE__, :last_message)
  end

  def handle_info({_udp, _socket, _host, _port, package}, messages) do
    {:noreply, [package | messages]}
  end

  def handle_call(:flush, _from, _messages) do
    {:reply, nil, [:nothing]}
  end

  def handle_call(:last_message, _from, messages) do
    IO.inspect(messages)
    {:reply, hd(messages), messages}
  end
end

TestUDPServer.start_link()
Watchman.start(nil, max_restarts: 20)
:timer.sleep(3000)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter], capture_log: true)
ExUnit.start(trace: true)
