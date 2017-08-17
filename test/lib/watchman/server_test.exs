defmodule Watchman.ServerTest do
  use ExUnit.Case

  test "host is not defined" do
    assert_raise RuntimeError, "Watchman Host is not defined", fn ->
      :ok = Application.put_env(:watchman, :host, nil)
      Watchman.Server.start_link(port: 8000, prefix: "a")
    end

    assert_raise RuntimeError, "Watchman Host is not defined", fn ->
      :ok = Application.put_env(:watchman, :host, "")
      Watchman.Server.start_link(port: 8000, prefix: "a")
    end
  end

  test "port is not defined" do
    assert_raise RuntimeError, "Watchman Port is not defined", fn ->
      :ok = Application.put_env(:watchman, :port, nil)
      Watchman.Server.start_link(host: "a", prefix: "a")
    end

    assert_raise RuntimeError, "Watchman Port is not defined", fn ->
      :ok = Application.put_env(:watchman, :port, "")
      Watchman.Server.start_link(host: "a", prefix: "a")
    end
  end

  test "prefix is not defined" do
    assert_raise RuntimeError, "Watchman Prefix is not defined", fn ->
      :ok = Application.put_env(:watchman, :prefix, nil)
      Watchman.Server.start_link(host: "a", port: 8888)
    end

    assert_raise RuntimeError, "Watchman Prefix is not defined", fn ->
      :ok = Application.put_env(:watchman, :prefix, "")
      Watchman.Server.start_link(host: "a", port: 8888)
    end
  end

end
