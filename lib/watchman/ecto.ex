defmodule Watchman.Ecto do
  @doc """
  Watchman.Ecto is a custom built ecto logger that submits transaction data
  to StatsD servers.

  To use the logger add this Logger to your ecto configuration.

  Example setup from `config/config.ex`:

    repo_name = "example_repo"

    config :my_app, MyApp.Repo,
      loggers: [
        {Ecto.LogEntry, :log, [:debug]},
        {Watchman.Ecto, :log, [repo_name]}
      ]

  When set up, this will generate the following metrics:

  1. total transaction counter
  <watchman-prefix>.transaction.count, with tags: [repo_name, table_name]

  2. the time spent executing the query in DB native units (nanosecs)
  <watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "query"]

  3. the time spent to check the connection out in DB native units (nanosecs)
  <watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "queue"]

  4. the time spent decoding the result in DB native units (nanosecs)
  <watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "decode"]

  5. total time spend for the transaction in DB native units (nanosecs)
  <watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "total"]
  """

  def log(entry, repo_name) do
    spawn(fn ->
      table = entry.source || "unknown"
      queue = entry.queue_time || 0
      query = entry.query_time || 0
      decode = entry.decode_time || 0
      total = queue + query + decode

      tags = [repo_name, table]

      Watchman.submit({"transaction.count", tags}, 1, :count)
      Watchman.submit({"transaction.duration", tags ++ ["query"]}, query, :timing)
      Watchman.submit({"transaction.duration", tags ++ ["queue"]}, queue, :timing)
      Watchman.submit({"transaction.duration", tags ++ ["decode"]}, decode, :timing)
      Watchman.submit({"transaction.duration", tags ++ ["total"]}, total, :timing)
    end)
  end
end
