defmodule Watchman.BenchmarkTest do
  use ExUnit.Case
  use Watchman.Benchmark

  @test_port 8125

  setup do
    TestUDPServer.start_link(port: @test_port)

    :ok
  end

  @benchmark(key: :auto)
  def simple1 do
    :timer.sleep(1000)
  end

  @benchmark(key: "charlie")
  def simple2 do
    :timer.sleep(500)
  end

  @benchmark(key: :auto)
  def add(a, b) do
    a + b
  end

  @benchmark(key: :auto)
  def minimum(a, b) when a < b do
    a
  end

  @benchmark(key: :auto)
  def minimum(a, b) when a >= b do
    b
  end

  test "benchmark annotation auto key test" do
    simple1

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.simple:10\d\d|ms/
  end

  test "benchmark annotation manual key test" do
    simple2

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.charlie:10\d\d|ms/
  end

  test "if function returns the proper return value" do
    result = add(1, 2)

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.add:\d*|ms/
    assert result == 3
  end

  test "function guards" do
    result = minimum(4, 2)

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.min:\d*|ms/
    assert result == 2
  end

end
