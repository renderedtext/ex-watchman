defmodule WatchmanHeartbeatTest do
  use ExUnit.Case

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  test "heartbeat test" do
    {:ok, hb} = Watchman.Heartbeat.start_link([interval: 1])
    :timer.sleep(2000)

    assert TestUDPServer.last_message == "watchman.test.heartbeat:1|g"
  end
end
