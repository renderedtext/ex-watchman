defmodule WatchmanTest do
  use ExUnit.Case, async: false
  use Watchman.Count

  @count(key: :auto)
  def test_function3 do
    :timer.sleep(200)
  end

  @count(key: "because.of.the.implication")
  def test_function4 do
    :timer.sleep(200)
  end

  test "submit with no type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit("user.count", 30)

    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.user.count:30|g"
  end

  test "submit with timing type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit("setup.duration", 30, :timing)
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.setup.duration:30|ms"
  end

  test "submit with counter type - 1 tag" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag.no_tag.no_tag.setup.duration:30|c"
  end

  test "submit with counter type - 3 tags" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "submit with counter type - 4 tags - dissregarded" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "increment with counter type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.increment("increment")
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.increment:1|c"
  end

  test "decrement with counter type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.decrement("decrement")
    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
            "tagged.watchman.test.no_tag.no_tag.no_tag.decrement:-1|c"
  end

  test "benchmark code execution" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.benchmark("sleep.duration", fn ->
      :timer.sleep(500)
    end)

    :timer.sleep(1000)

    assert TestUDPServer.last_message =~ ~r/watchman.test.sleep.duration:5\d\d|ms/
  end

  test "count annotation auto key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    test_function3

    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
      "tagged.watchman.test.no_tag.no_tag.no_tag.watchman_test.test_function3:1|c"
  end

  test "count annotation manual key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    test_function4

    :timer.sleep(1000)

    assert TestUDPServer.last_message ==
      "tagged.watchman.test.no_tag.no_tag.no_tag.because.of.the.implication:1|c"
  end

  test "submitting metrics to watchman is fast" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    {time, :ok} = :timer.tc(fn ->
      Enum.each(1..1000, fn _ -> Watchman.increment("increment") end)
    end)

    IO.puts "\nSubmiting to watchman took: #{time}ms"

    #
    # submitting 1000 metrics should take less then a 5 miliseconds
    #
    # We only want a referent duration here that is acceptable.
    #
    assert time/1000 < 5
  end

  test "watchman server has an upper limit of metrics" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    max_buffer_size = Watchman.Server.max_buffer_size()
    pid = Process.whereis(Watchman.Server)

    Enum.each(1..(max_buffer_size*5), fn _ -> Watchman.increment("increment") end)

    {:message_queue_len, len} = Process.info(pid, :message_queue_len)

    IO.puts "\nMessage queue len: #{len}"

    assert len <= max_buffer_size
  end

  describe ".whitelist" do
    setup do
      # TestHelpers.start_with_opts(whitelist: "^external.*")
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      pid = Process.whereis(Watchman.Server)
      Process.exit(pid, :kill)
      Watchman.Server.start_link([whitelist: "^external.*"])


      :timer.sleep(1000)
      # on_exit(fn -> TestHelpers.start_with_opts() end)
      :ok
    end

    test "watchman server does not forward topic that is not whitelisted" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.Server.buffer_size
      Watchman.submit("external.user.count", 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message ==
              "tagged.watchman.test.no_tag.no_tag.no_tag.external.user.count:30|g"

      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit("internal.user.count", 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message == :nothing
    end
  end
end
