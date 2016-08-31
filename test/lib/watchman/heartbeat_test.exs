defmodule WatchmanHeartbeatTest do
  use ExUnit.Case

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  test "heartbeat test" do
    {:ok, hb} = Watchman.Heartbeat.start_link([interval: 1])
    :timer.sleep(5000)

    assert TestUDPServer.last_message == "watchman.test.heartbeat:4|g"

    :timer.sleep(3000)

    assert TestUDPServer.last_message == "watchman.test.heartbeat:7|g"
  end
end
