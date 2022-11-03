defmodule Watchman.Server do
  use GenServer
  require Logger

  def start_link(options \\ []) do
    state = %{
      host: options[:host] || Application.get_env(:watchman, :host),
      port: options[:port] || Application.get_env(:watchman, :port),
      prefix: options[:prefix] || Application.get_env(:watchman, :prefix),
      socket: nil,
      external_only:
        options[:external_only] || Application.get_env(:watchman, :external_only, false)
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
    case host |> to_char_list |> :inet.parse_address() do
      {:error, _} -> host |> String.to_atom()
      {:ok, address} -> address
    end
  end

  def handle_cast({:send, names_list, value, type}, state) do
    if should_publish(state.external_only, names_list) do
      name_and_tag = get_name_and_tag(state.external_only, names_list)
      handle_cast_(name_and_tag, value, type, state)
    end

    {:noreply, state}
  end

  def handle_cast_(name, value, type, state) when not is_tuple(name) do
    handle_cast_({name, []}, value, type, state)
  end

  def handle_cast_({name, tag_list}, value, type, state) do
    package = statsd_package(state.prefix, name, tag_list |> tags, value, type)

    :gen_udp.send(state.socket, state.host, state.port, package)
    {:noreply, state}
  end

  defp should_publish(external_only, external) do
    if external_only do
      Enum.any?(external, fn e -> elem(e, 0) in [:external, :always] end)
    else
      Enum.any?(external, fn e -> elem(e, 0) in [:internal, :always] end)
    end
  end

  defp get_name_and_tag(external_only, names_list) do
    if external_only do
      Enum.find(names_list, fn e -> elem(e, 0) in [:external, :always] end)
    else
      Enum.find(names_list, fn e -> elem(e, 0) in [:internal, :always] end)
    end
    |> elem(1)
  end

  defp statsd_package(prefix, name, tags, value, :gauge) do
    "tagged.#{prefix}.#{tags}.#{name}:#{value}|g"
  end

  defp statsd_package(prefix, name, tags, value, :timing) do
    "tagged.#{prefix}.#{tags}.#{name}:#{value}|ms"
  end

  defp statsd_package(prefix, name, tags, value, :count) do
    "tagged.#{prefix}.#{tags}.#{name}:#{value}|c"
  end

  @no_tag ~w(no_tag no_tag no_tag)
  defp tags(tag_list) do
    (tag_list ++ @no_tag)
    |> Enum.take(3)
    |> Enum.join(".")
  end
end
