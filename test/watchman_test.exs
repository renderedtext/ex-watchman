defmodule WatchmanTest do
  use ExUnit.Case
  use Watchman

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

  test "count annotation auto key test" do
    test_function3

    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.watchman_test.test_function3:1|c"
  end

  test "count annotation manual key test" do
    test_function4

    :timer.sleep(500)

    assert TestUDPServer.last_message == "watchman.test.because.of.the.implication:1|c"
  end

end
