defmodule WatchmanTest do
  use ExUnit.Case

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  test "submit with no type" do
    Watchman.submit("user.count", 30)

    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.user.count:30|g"
  end

  test "submit with timing type" do
    Watchman.submit("setup.duration", 30, :timing)
    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.setup.duration:30|ms"
  end

  test "increment with counter type" do
    Watchman.increment("increment")
    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.increment:1|c"
  end

  test "decrement with counter type" do
    Watchman.decrement("decrement")
    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.decrement:-1|c"
  end

  test "benchmark code execution" do
    Watchman.benchmark("sleep.duration", fn ->
      :timer.sleep(500)
    end)

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.sleep.duration:5\d\d|ms/
  end

end
