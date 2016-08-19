defmodule WatchmanHeartbeatTest do
  use ExUnit.Case

  @test_port 33322

  setup do
    TestUDPServer.start_link(port: @test_port)

    {:ok, _watchman} = Watchman.start_link([
      host: 'localhost',
      port: @test_port,
      prefix: "test.prod"
    ])

    :ok
  end

  test "heartbeat test" do
    {:ok, hb} = Watchman.Heartbeat.start_link([name: "heartbeat", interval: 1])
    :timer.sleep(2000)
    GenServer.stop(hb)
    assert TestUDPServer.last_message == "test.prod.heartbeat:1|g"
  end
end
