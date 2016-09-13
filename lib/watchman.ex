defmodule Watchman do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Watchman.Server, []),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  def submit(name, value, type \\ :gauge) do
    GenServer.cast(Watchman.Server, {:send, name, value, type})
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


#########################################################################


  defmodule Benchmark do
    defstruct method_name: nil, key: nil, units: :micros, args: nil, guards: nil, body: nil
  end

  defmacro __using__(_mod) do

    quote do
      import Watchman
      IO.puts "If you see this, that means that __using__ is currently running!"
      # all the benchmarked methods will go here
      Module.register_attribute(__MODULE__, :watchman_benchmarks, accumulate: true)
      @before_compile Watchman
      @on_definition Watchman
    end
  end

  def __on_definition__(env, _kind, name, args, guards, body) do
    mod = env.module
    # is there a @benchmark before it?
    benchmark_info = Module.get_attribute(mod, :benchmark)

    IO.puts "If you see this, that means that __on_definition__ is currently running!"
    IO.puts "Benchmark_info: #{benchmark_info}"

    if benchmark_info do

      prefix = mod
      |> inspect
      |> String.replace(~r/([a-z])([A-Z])/, ~S"\1_\2")
      |> String.downcase

      # the key that will be used when sending the data about the function
      key = "#{prefix}.#{name}"

      # where is this needed?
      units = benchmark_info[:units] || :micros

      # add this function as one of the benchmarked ones
      Module.put_attribute(mod, :watchman_benchmarks,
                           %Benchmark{method_name: name,
                                  args: args,
                                  guards: guards,
                                  body: body,
                                  units: units,
                                  key: key})

      Module.delete_attribute(mod, :benchmark)
    end
  end

  defp build_benchmark_body(benchmark_data=%Benchmark{}) do
    # inject a Watchman.benchmark between the function definition (def name) and the body,
    # so that the time taken to execute the function body can be measured
    quote do
      Watchman.benchmark(unquote(benchmark_data.key), fn (unquote_splicing(benchmark_data.args)) ->
        unquote(benchmark_data.body)
        IO.puts "Key: #{benchmark_data.key}"
        IO.puts "Name: #{benchmark_data.method_name}"
      end)
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module

    IO.puts "If you see this, that means that __before_compile__ is currently running!"

    benchmarks = Module.get_attribute(mod, :watchman_benchmarks)
    benchmarked_methods = benchmarks
    # what is this for?
    |> Enum.reverse
    |> Enum.map(
        fn(benchmark_data=%Benchmark{}) ->
          # make the function with @benchmark overridable so that the Watchman.benchmark can be injected
          Module.make_overridable(mod,
                                  [{benchmark_data.method_name, length(benchmark_data.args)}])
          body = build_benchmark_body(benchmark_data)

          # from this:
          #     @benchmark
          #     def function(arguments) guards do
          #       body
          #     end
          # it should go to this:
          #     def function(arguments) guards do
          #       Watchman.benchmark(key, fn (arguments) ->
          #         body
          #       end)
          #     end
          #

          if length(benchmark_data.guards) > 0 do
            # like writing a function: write 'def' then its name then the arguments and the guards, if
            # there are any; then put the function body, which was modified by adding the
            # 'Watchman.benchmark' to it
            quote do
              def unquote(benchmark_data.method_name)(unquote_splicing(benchmark_data.args)) when unquote_splicing(benchmark_data.guards) do
                unquote(body)
              end
            end

          else
            quote do
              def unquote(benchmark_data.method_name)(unquote_splicing(benchmark_data.args))  do
                unquote(body)
              end
            end
          end
        end)

    quote do
      unquote_splicing(benchmarked_methods)
    end
  end


########################################################################


end
