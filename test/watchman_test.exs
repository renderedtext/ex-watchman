defmodule WatchmanTest do
  use ExUnit.Case
  use Watchman.Count

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  @count(key: :auto)
  def test_function3 do
    :timer.sleep(200)
  end

  @count(key: "because.of.the.implication")
  def test_function4 do
    :timer.sleep(200)
  end

  test "submit with no type" do
    Watchman.submit("user.count", 30)

    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.user.count:30|g"
  end

  test "submit with timing type" do
    Watchman.submit("setup.duration", 30, :timing)
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.setup.duration:30|ms"
  end

  test "submit with counter type - 1 tag" do
    Watchman.submit({"setup.duration", [:tag]}, 30, :count)
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag.no_tag.no_tag.setup.duration:30|c"
  end

  test "submit with counter type - 3 tags" do
    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "submit with counter type - 4 tags - dissregarded" do
    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "increment with counter type" do
    Watchman.increment("increment")
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.increment:1|c"
  end

  test "decrement with counter type" do
    Watchman.decrement("decrement")
    :timer.sleep(500)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.decrement:-1|c"
  end

  test "benchmark code execution" do
    Watchman.benchmark("sleep.duration", fn ->
      :timer.sleep(500)
    end)

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.sleep.duration:5\d\d|ms/
  end

  test "count annotation auto key test" do
    test_function3

    :timer.sleep(500)

    assert TestUDPServer.last_message ==
      "tagged.watchman.test.no_tag.no_tag.no_tag.watchman_test.test_function3:1|c"
  end

  test "count annotation manual key test" do
    test_function4

    :timer.sleep(500)

    assert TestUDPServer.last_message ==
      "tagged.watchman.test.no_tag.no_tag.no_tag.because.of.the.implication:1|c"
  end

  test "sending metrics to a broken statsd" do
    Enum.each(1..1000, fn _ ->
      Watchman.increment("increment")
    end)

    :timer.sleep(1000)

    pid = Process.whereis(Watchman.Server)
    assert Process.info(pid, :message_queue_len) == {:message_queue_len, 0}
  end

end
