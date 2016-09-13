defmodule WatchmanTest do
  use ExUnit.Case
  use Watchman.Benchmark

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  @benchmark(key: :auto)
  def test_function1 do
    :timer.sleep(1000)
  end

  @benchmark(key: "goddammit.charlie")
  def test_function2 do
    :timer.sleep(500)
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

  test "benchmark annotation auto key test" do
    test_function1

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman_test.test_function1:10\d\d|ms/
  end

  test "benchmark annotation manual key test" do
    test_function2

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.goddammit.charlie:5\d\d|ms/
  end

end
