defmodule WatchmanHeartbeatTest do
  use ExUnit.Case, async: false

  test "heartbeat test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    {:ok, _hb} = Watchman.Heartbeat.start_link(interval: 1)
    :timer.sleep(5000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.heartbeat:4|g"

    :timer.sleep(3000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.heartbeat:7|g"
  end
end
