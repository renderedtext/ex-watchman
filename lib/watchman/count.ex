defmodule Watchman.Count do

  defmodule CountedMethod do
    defstruct method_name: nil, key: nil, args: nil, guards: nil, body: nil
  end

  defmacro __using__(_mod) do
    quote do
      import Watchman
      # all the methods which are being counted will go here
      Module.register_attribute(__MODULE__, :watchman_counts, accumulate: true)
      @before_compile Watchman.Count
      @on_definition Watchman.Count
    end
  end

  def __on_definition__(env, _kind, name, args, guards, body) do
    mod = env.module
    # is there a @count() before it?
    count_info = Module.get_attribute(mod, :count)

    if count_info do

      key = case count_info[:key] do
              :auto ->
                # Convert a fully qualified module to an underscored representation.
                # Module.SubModule.SubSubModule will become
                # module.sub_module.sub_sub_module
                prefix = mod
                |> inspect
                |> String.replace(~r/([a-z])([A-Z])/, ~S"\1_\2")
                |> String.downcase

                "#{prefix}.#{name}"

              other ->
                if String.contains?(other, " ") do
                  raise "The key contains blank spaces! Try replacing them with '.'!"
                end
                other
            end

      # add this function as one of the benchmarked ones
      Module.put_attribute(mod, :watchman_counts,
                           %CountedMethod{method_name: name,
                                  args: args,
                                  guards: guards,
                                  body: body,
                                  key: key})

      Module.delete_attribute(mod, :count)
    end
  end

  defp add_count_to_body(count_data=%CountedMethod{}) do
    # add a Watchman.increment before the function body, so that every time
    # the function is called, the increment is called also
    quote do
      Watchman.increment(unquote(count_data.key))
      unquote(count_data.body)
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module

    counts = Module.get_attribute(mod, :watchman_counts)
    counted_methods = counts
    |> Enum.reverse
    |> Enum.map(
        fn(count_data=%CountedMethod{}) ->
          # make the function with @count overridable so that the Watchman.increment can be added
          Module.make_overridable(mod,
                                  [{count_data.method_name, length(count_data.args)}])
          body = add_count_to_body(count_data)

          # from this:
          #     @count
          #     def function(arguments) guards do
          #       body
          #     end
          # it should go to this:
          #     def function(arguments) guards do
          #       Watchman.increment(key)
          #       body
          #     end
          #

          if length(count_data.guards) > 0 do
            # like writing a function: write 'def' then its name then the arguments and the guards, if
            # there are any; then put the function body, which was modified by adding the
            # 'Watchman.increment'
            quote do
              def unquote(count_data.method_name)(unquote_splicing(count_data.args)) when unquote_splicing(count_data.guards) do
                unquote(body)
              end
            end

          else
            quote do
              def unquote(count_data.method_name)(unquote_splicing(count_data.args))  do
                unquote(body)
              end
            end
          end
        end)

    quote do
      unquote_splicing(counted_methods)
    end
  end

end
