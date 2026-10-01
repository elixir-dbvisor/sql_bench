defmodule SqlBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :sql_bench,
      version: "0.1.0",
      elixir: "~> 1.20-rc",
      start_permanent: Mix.env() == :prod,
      compilers: [:sql] ++ Mix.compilers(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :sql]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      {:sql, github: "elixir-dbvisor/sql"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
    ]
  end
end
