defmodule Watchman.Server do
  use GenServer
  require Logger

  def start_link(options \\ []) do
    state = %{
      host: options[:host] || Application.get_env(:watchman, :host),
      port: options[:port] || Application.get_env(:watchman, :port),
      prefix: options[:prefix] || Application.get_env(:watchman, :prefix)
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

    state = %{ state | host: parse_host(state.host) }

    Logger.info "Watchman sending metrics to #{state.host}:#{state.port} with prefix '#{state.prefix}'"

    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  defp parse_host(host) when is_binary(host) do
    case host |> to_char_list |> :inet.parse_address do
      {:error, _}    -> host |> String.to_atom
      {:ok, address} -> address
    end
  end

  def handle_cast({:send, {name, tags}, value, type}, state) when is_list(tags) do
    handle_cast_(name, tags, value, type, state)
  end
  def handle_cast({:send, name, value, type}, state) do
    handle_cast_(name, [], value, type, state)
  end

  def handle_cast_(name, tag_list, value, type, state) do
    package = statsd_package(state.prefix, name, tag_list |> tags, value, type)
    {:ok, socket} = :gen_udp.open(0, [:binary])
    :gen_udp.send(socket, state.host, state.port, package)
    :gen_udp.close(socket)

    {:noreply, state}
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
    tag_list ++ @no_tag
    |> Enum.take(3)
    |> Enum.join(".")
  end

end
