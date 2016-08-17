defmodule WatchmanTest do
  use ExUnit.Case
  doctest Watchman

  @test_port 33322

  setup do
    TestUDPServer.start_link(port: @test_port)

    {:ok, watchman} = Watchman.start_link([
      host: 'localhost',
      port: @test_port,
      prefix: "test.prod"
    ])

    :ok
  end

  test "submit with no type" do
    Watchman.submit("user.count", 30)
    :timer.sleep(500)

    assert TestUDPServer.last_message == "test.prod.user.count:30|g"
  end

  test "submit with timing type" do
    Watchman.submit("setup.duration", 30, :timing)
    :timer.sleep(500)

    assert TestUDPServer.last_message == "test.prod.setup.duration:30|ms"
  end

  test "benchmark code execution" do
    Watchman.benchmark("sleep.duration", fn ->
      :timer.sleep(500)
    end)

    :timer.sleep(500)

    assert TestUDPServer.last_message =~ ~r/test.prod.sleep.duration:5\d\d|ms/
  end

end
