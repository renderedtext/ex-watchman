defmodule WatchmanTest do
  use ExUnit.Case, async: false
  use Watchman.Count

  @count key: :auto
  def test_function3 do
    :timer.sleep(200)
  end

  @count key: "because.of.the.implication"
  def test_function4 do
    :timer.sleep(200)
  end

  test "submit with no type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit("user.count", 30)

    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.user.count:30|g"
  end

  test "submit with timing type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit("setup.duration", 30, :timing)
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.setup.duration:30|ms"
  end

  test "submit with counter type - 1 tag" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.tag.no_tag.no_tag.setup.duration:30|c"
  end

  test "submit with counter type - 3 tags" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "submit with counter type - 4 tags - dissregarded" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30, :count)
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.tag1.tag2.tag3.setup.duration:30|c"
  end

  test "increment with counter type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.increment("increment")
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.increment:1|c"
  end

  test "decrement with counter type" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.decrement("decrement")
    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.decrement:-1|c"
  end

  test "benchmark code execution" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    Watchman.benchmark("sleep.duration", fn ->
      :timer.sleep(500)
    end)

    :timer.sleep(1000)

    assert TestUDPServer.last_message() =~ ~r/watchman.test.sleep.duration:5\d\d|ms/
  end

  test "count annotation auto key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    test_function3()

    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.watchman_test.test_function3:1|c"
  end

  test "count annotation manual key test" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    test_function4()

    :timer.sleep(1000)

    assert TestUDPServer.last_message() ==
             "tagged.watchman.test.no_tag.no_tag.no_tag.because.of.the.implication:1|c"
  end

  test "submitting metrics to watchman is fast" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    {time, :ok} =
      :timer.tc(fn ->
        Enum.each(1..1000, fn _ -> Watchman.increment("increment") end)
      end)

    IO.puts("\nSubmiting to watchman took: #{time}ms")

    #
    # submitting 1000 metrics should take less then a 10 milliseconds
    #
    # We only want a referent duration here that is acceptable.
    #
    assert time / 1000 < 10
  end

  test "watchman server has an upper limit of metrics" do
    TestUDPServer.wait_for_clean_message_box()
    TestUDPServer.flush()

    max_buffer_size = Watchman.Server.max_buffer_size()
    pid = Process.whereis(Watchman.Server)

    Enum.each(1..(max_buffer_size * 5), fn _ -> Watchman.increment("increment") end)

    {:message_queue_len, len} = Process.info(pid, :message_queue_len)

    IO.puts("\nMessage queue len: #{len}")

    assert len <= max_buffer_size
    # allow Watchman.Server time to clear it's buffer
    :timer.sleep(1000)
  end

  describe ".send_only :external" do
    setup do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      if Application.get_env(:watchman, :send_only) != :external do
        Application.put_env(:watchman, :send_only, :external)
        pid = Process.whereis(Watchman.Server)
        Process.exit(pid, :kill)

        :timer.sleep(1000)
      end

      on_exit(fn ->
        Application.put_env(:watchman, :send_only, :internal)
        pid = Process.whereis(Watchman.Server)
        Process.exit(pid, :kill)
        :timer.sleep(500)
      end)

      :ok
    end

    test "flag not sent => do not forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit("internal.user.count", 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() == :nothing
    end

    test "flag :always => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:always, "internal.user.count"}, 31)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.internal.user.count:31|g"
    end

    test "flag :external => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:external, "external.user.count"}, 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.external.user.count:30|g"
    end

    test "flag :external, type :timing => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:external, "external.user.count"}, 30, :timing)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.external.user.count:30|ms"
    end

    test "flag :internal => do not forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:internal, "internal.user.count"}, 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() == :nothing
    end

    test "both :internal and external => forward and use external name" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit([internal: "internal.user.count", external: "external.user.count"], 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.external.user.count:30|g"
    end

    test "flag :external with tags => forward with flags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:external, {"external.user.count", ["first_tag", "zwei_tag"]}}, 50)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.first_tag.zwei_tag.no_tag.external.user.count:50|g"
    end

    test "flag :external with tags, :internal with no flags => forward with flags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit(
        [
          internal: "internal.user.count",
          external: {"external.user.count", ["first_tag", "zwei_tag"]}
        ],
        50
      )

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.first_tag.zwei_tag.no_tag.external.user.count:50|g"
    end
  end

  describe ".send_only :internal" do
    setup do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      if Application.get_env(:watchman, :send_only, :internal) != :internal do
        Application.put_env(:watchman, :send_only, :internal)
        pid = Process.whereis(Watchman.Server)
        Process.exit(pid, :kill)

        :timer.sleep(1000)
      end

      on_exit(fn ->
        Application.put_env(:watchman, :send_only, :internal)
        pid = Process.whereis(Watchman.Server)
        Process.exit(pid, :kill)
        :timer.sleep(500)
      end)

      :ok
    end

    test "flag not sent => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit("internal.user.count", 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.internal.user.count:30|g"
    end

    test "flag :always => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:always, "internal.user.count"}, 30, :gauge)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.internal.user.count:30|g"
    end

    test "flag :external => do not forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:external, "internal.user.count"}, 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() == :nothing
    end

    test "flag :internal => forward" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({:internal, "internal.user.count"}, 30)

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.internal.user.count:30|g"
    end

    test "flag :external with tags, :internal with no flags => forward without flags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit(
        [
          internal: "internal.user.count",
          external: {"external.user.count", ["first_tag", "zwei_tag"]}
        ],
        50
      )

      :timer.sleep(1000)

      assert TestUDPServer.last_message() ==
               "tagged.watchman.test.no_tag.no_tag.no_tag.internal.user.count:50|g"
    end
  end

  describe ".external_backend: :aws_cloudwatch" do
    setup do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      if Application.get_env(:watchman, :external_backend) != :aws_cloudwatch do
        :timer.sleep(2000)
        Application.put_env(:watchman, :external_backend, :aws_cloudwatch)
        pid = Process.whereis(Watchman.Server)
        Process.exit(pid, :kill)

        :timer.sleep(1000)
      end

      on_exit(fn ->
        if Application.get_env(:watchman, :external_backend, :statsd_graphite) != :statsd_graphite do
          Application.put_env(:watchman, :external_backend, :statsd_graphite)
          pid = Process.whereis(Watchman.Server)
          Process.exit(pid, :kill)
          :timer.sleep(500)
        end
      end)

      :ok
    end

    test "metric without tags => do not add tags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      # Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30)
      Watchman.submit("setup.duration", 30)

      :timer.sleep(200)

      assert TestUDPServer.last_message() ==
               "watchman.test.setup.duration:30|g"
    end

    test "metric with unnamed tags => add tags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({"setup.duration", [:tag1, :tag2, :tag3]}, 30)

      :timer.sleep(200)

      assert TestUDPServer.last_message() ==
               "watchman.test.setup.duration:30|g|#tag1:tag1,tag2:tag2,tag3:tag3"
    end

    test "metric with named tags as keyword list=> add tags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({"setup.duration", [tagA: :tag1, tagB: :tag2, tagC: :tag3]}, 30)

      :timer.sleep(200)

      assert TestUDPServer.last_message() ==
               "watchman.test.setup.duration:30|g|#tagA:tag1,tagB:tag2,tagC:tag3"
    end

    test "metric with named tags as a map => add tags" do
      TestUDPServer.wait_for_clean_message_box()
      TestUDPServer.flush()

      Watchman.submit({"setup.duration", %{tagA: :tag1, tagB: :tag2, tagC: :tag3}}, 30)

      :timer.sleep(200)

      assert TestUDPServer.last_message() ==
               "watchman.test.setup.duration:30|g|#tagA:tag1,tagB:tag2,tagC:tag3"
    end
  end
end
