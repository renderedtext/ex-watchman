defmodule Watchman.Server do
  use GenServer
  require Logger

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(options \\ []) do
    state = %{
      host: options[:host] || Application.get_env(:watchman, :host),
      port: options[:port] || Application.get_env(:watchman, :port),
      prefix: options[:prefix] || Application.get_env(:watchman, :prefix),
      socket: nil,
      send_only: options[:send_only] || Application.get_env(:watchman, :send_only, :internal),
      external_backend:
        options[:external_backend] ||
          Application.get_env(:watchman, :external_backend, :statsd_graphite)
    }

    if state[:host] == nil || state[:host] == "" do
      raise "Watchman Host is not defined"
    end

    if state[:port] == nil || state[:port] == "" do
      raise "Watchman Port is not defined"
    end

    if state[:prefix] == nil || state[:prefix] == "" do
      raise "Watchman Prefix is not defined"
    end

    Logger.info(
      "Watchman sending metrics to #{state.host}:#{state.port} with prefix '#{state.prefix}'"
    )

    state = %{state | host: parse_host(state.host)}

    {:ok, socket} = :gen_udp.open(0, [:binary])

    state = %{state | socket: socket}

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  def max_buffer_size do
    Application.get_env(:watchman, :max_buffer_size) || 10000
  end

  def buffer_size do
    pid = Process.whereis(__MODULE__)

    {:message_queue_len, len} = Process.info(pid, :message_queue_len)

    len
  end

  def submit(name, value, type) when is_tuple(name), do: submit([name], value, type)

  def submit(name, value, type) do
    if buffer_size() < max_buffer_size() - 1 do
      GenServer.cast(__MODULE__, {:send, name, value, type})
    else
      :ok
    end
  end

  defp parse_host(host) when is_binary(host) do
    case host |> to_charlist() |> :inet.parse_address() do
      {:error, _} -> host |> String.to_atom()
      {:ok, address} -> address
    end
  end

  def handle_cast({:send, names, value, type}, state) do
    if should_publish(state.send_only, names) do
      name_and_tag = get_name_and_tag(state.send_only, names)
      handle_cast_(name_and_tag, value, type, state)
    end

    {:noreply, state}
  end

  def handle_cast_(name, value, type, state) when not is_tuple(name) do
    handle_cast_({name, []}, value, type, state)
  end

  def handle_cast_({name, tag_list}, value, type, state) do
    package = statsd_package(state.prefix, name, tag_list, value, type, state.external_backend)

    :gen_udp.send(state.socket, state.host, state.port, package)
    {:noreply, state}
  end

  defp should_publish(send_only, names) do
    Keyword.has_key?(names, send_only) || Keyword.has_key?(names, :always)
  end

  defp get_name_and_tag(send_only, names) do
    Keyword.get(names, send_only) || Keyword.get(names, :always)
  end

  defp statsd_package(prefix, name, tag_list, value, type, :statsd_graphite) do
    tags = tag_list |> tags
    "tagged.#{prefix}.#{tags}.#{name}:#{value}|" <> metric_type(type)
  end

  defp statsd_package(prefix, name, tags, value, type, :aws_cloudwatch) do
    "#{prefix}.#{name}:#{value}|" <> metric_type(type) <> tags_package(tags)
  end

  defp tags_package(tags) do
    tag_str =
      if Keyword.keyword?(tags) or is_map(tags) do
        Enum.map(tags, fn {k, v} -> "#{k}:#{v}" end) |> Enum.join(",")
      else
        tagger(tags, [], 1)
        |> Enum.reverse()
        |> Enum.join(",")
      end

    if String.length(tag_str) > 0, do: "|##{tag_str}", else: ""
  end

  defp tagger([], acc, _index), do: acc

  defp tagger([h | t], acc, index) do
    tagger(t, ["tag#{index}:#{h}" | acc], index + 1)
  end

  defp metric_type(:gauge), do: "g"
  defp metric_type(:timing), do: "ms"
  defp metric_type(:count), do: "c"

  @no_tag ~w(no_tag no_tag no_tag)
  defp tags(tag_list) do
    (tag_list ++ @no_tag)
    |> Enum.take(3)
    |> Enum.join(".")
  end
end
