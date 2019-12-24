defmodule Exlastic.MixProject do
  use Mix.Project

  def project do
    [
      app: :exlastic,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {Exlastic.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tirexs, "~> 0.8"},
      {:telemetry, "~> 0.4"},
      {:jason, "~> 1.0"}
    ]
  end
end
