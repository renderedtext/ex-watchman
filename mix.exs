defmodule Watchman.Mixfile do
  use Mix.Project

  def project do
    [app: :watchman,
     version: "0.2.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [mod: {Watchman, []}, applications: [:logger]]
  end

  defp deps do
    []
  end
end
