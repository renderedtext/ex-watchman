defmodule Watchman do
  use Application

  def start(_type, args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Watchman.Server, []),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    opts = Keyword.merge(opts, args)

    Supervisor.start_link(children, opts)
  end

  def submit(name, value, type \\ :gauge)

  def submit({external, name}, value, type) when external in [:internal, :external, :always] do
    Watchman.Server.submit([{external, name}], value, type)
  end

  def submit(name_list, value, type) when is_list(name_list) do
    Watchman.Server.submit(name_list, value, type)
  end

  def submit(name, value, type) do
    Watchman.Server.submit([{:internal, name}], value, type)
  end

  def increment(name_list) when is_list(name_list) do
    submit(name_list, 1, :count)
  end

  def increment({external, name}) when external in [:internal, :external, :always] do
    submit([{external, name}], 1, :count)
  end

  def increment(name), do: increment({:internal, name})

  def decrement(name_list) when is_list(name_list) do
    submit(name_list, -1, :count)
  end

  def decrement(name = {type, _}) when type in [:internal, :external, :always] do
    submit([name], -1, :count)
  end

  def decrement(name), do: decrement({:internal, name})

  def benchmark(name_list, function) when is_list(name_list) do
    {duration, result} = function |> :timer.tc()
    submit(name_list, div(duration, 1000), :timing)
    result
  end

  def benchmark(name = {type, _}, function) when type in [:internal, :external, :always] do
    benchmark([name], function)
  end

  def benchmark(name, function), do: benchmark({:internal, name}, function)
end
