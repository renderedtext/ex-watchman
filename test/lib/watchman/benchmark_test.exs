defmodule Watchman.BenchmarkTest do
  use ExUnit.Case, async: false
  use Watchman.Benchmark

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
  def sum(a, b) when is_integer(a) and is_integer(b) do
    a + b
  end
  def sum(a, b) when is_list(a) and is_list(b) do
    a ++ b
  end
  def sum(a, b) when is_binary(a) and is_binary(b) do
    a <> b
  end

  test "benchmark annotation auto key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    simple1

    :timer.sleep(1000)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.simple:10\d\d|ms/
  end

  test "benchmark annotation manual key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    simple2

    :timer.sleep(1000)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.charlie:10\d\d|ms/
  end

  test "function returns the proper return value" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    result = add(1, 2)

    :timer.sleep(1000)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.add:\d*|ms/
    assert result == 3
  end

  test "function guards" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    result = sum(3, 5)

    :timer.sleep(1000)

    assert TestUDPServer.last_message =~ ~r/watchman.test.watchman.benchmark_test.sum:\d*|ms/
    assert result == 8
  end

end
