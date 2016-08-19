defmodule Watchman do
  use GenServer

  def start_link(options \\ []) do
    state = %{
      host: (options[:host] || Application.get_env(:watchman, :host)) |> parse_host,
      port: options[:port] || Application.get_env(:watchman, :port),
      prefix: options[:prefix] || Application.get_env(:watchman, :prefix)
    }

    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  def submit(name, value, type \\ :gauge) do
    GenServer.cast(__MODULE__, {:send, name, value, type})
  end

  def increment(name) do
    submit(name, 1, :count)
  end

  def decrement(name) do
    submit(name, -1, :count)
  end

  def benchmark(name, function) do
    {duration, result} = function |> :timer.tc

    submit(name, div(duration, 1000))

    result
  end

  defp parse_host(host) when is_binary(host) do
    case host |> to_char_list |> :inet.parse_address do
      {:error, _}    -> host |> String.to_atom
      {:ok, address} -> address
    end
  end

  # Server

  def handle_cast({:send, name, value, type}, state) do
    package = statsd_package(state.prefix, name, value, type)

    {:ok, socket} = :gen_udp.open(0, [:binary])
    :gen_udp.send(socket, state.host, state.port, package)
    :gen_udp.close(socket)

    {:noreply, state}
  end

  defp statsd_package(prefix, name, value, :gauge) do
    "#{prefix}.#{name}:#{value}|g"
  end

  defp statsd_package(prefix, name, value, :timing) do
    "#{prefix}.#{name}:#{value}|ms"
  end

  defp statsd_package(prefix, name, value, :count) do
    "#{prefix}.#{name}:#{value}|c"
  end

end
