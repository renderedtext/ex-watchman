defmodule Watchman.Benchmark do
  defmodule BenchmarkedMethod do
    defstruct method_name: nil, key: nil, args: nil, guards: nil, body: nil
  end

  defmacro __using__(_mod) do
    quote do
      import Watchman
      # all the benchmarked methods will go here
      Module.register_attribute(__MODULE__, :watchman_benchmarks, accumulate: true)
      @before_compile Watchman.Benchmark
      @on_definition Watchman.Benchmark
    end
  end

  def __on_definition__(env, _kind, name, args, guards, body) do
    mod = env.module
    # is there a @benchmark() before it?
    benchmark_info = Module.get_attribute(mod, :benchmark)

    if benchmark_info do
      key =
        case benchmark_info[:key] do
          :auto ->
            # Convert a fully qualified module to an underscored representation.
            # Module.SubModule.SubSubModule will become
            # module.sub_module.sub_sub_module
            prefix =
              mod
              |> inspect
              |> String.replace(~r/([a-z])([A-Z])/, ~S"\1_\2")
              |> String.downcase()

            "#{prefix}.#{name}"

          other ->
            if String.contains?(other, " ") do
              raise "The key contains blank spaces! Try replacing them with '.'!"
            end

            other
        end

      method = %BenchmarkedMethod{
        method_name: name,
        args: args,
        guards: guards,
        body: body,
        key: key
      }

      # add this function as one of the benchmarked ones
      Module.put_attribute(mod, :watchman_benchmarks, method)

      Module.delete_attribute(mod, :benchmark)
    end
  end

  defp build_benchmark_body(benchmark_data = %BenchmarkedMethod{}) do
    # inject a Watchman.benchmark between the function definition (def name) and the body,
    # so that the time taken to execute the function body can be measured
    quote do
      Watchman.benchmark(unquote(benchmark_data.key), fn ->
        unquote(Keyword.get(benchmark_data.body, :do))
      end)
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module

    benchmarks = Module.get_attribute(mod, :watchman_benchmarks)

    benchmarked_methods =
      benchmarks
      |> Enum.reverse()
      |> Enum.map(fn benchmark_data = %BenchmarkedMethod{} ->
        # make the function with @benchmark overridable so that the Watchman.benchmark can be injected
        Module.make_overridable(
          mod,
          [{benchmark_data.method_name, length(benchmark_data.args)}]
        )

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
            def unquote(benchmark_data.method_name)(unquote_splicing(benchmark_data.args))
                when unquote_splicing(benchmark_data.guards) do
              unquote(body)
            end
          end
        else
          quote do
            def unquote(benchmark_data.method_name)(unquote_splicing(benchmark_data.args)) do
              unquote(body)
            end
          end
        end
      end)

    quote do
      (unquote_splicing(benchmarked_methods))
    end
  end
end
