defmodule Gelato.MixProject do
  use Mix.Project

  @app :gelato
  @version "0.2.0"
  @owner "kantox"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: ["test.cluster": :test],
      xref: [exclude: []],
      description: description(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_deps: :transitive,
        plt_add_apps: [],
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :jason, :inets, :ssl],
      mod: {Gelato.Application, []}
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 0.4"},
      {:jason, "~> 1.0"},
      # utilities
      {:credo, "~> 1.0", only: [:dev, :ci]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :ci], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, override: true}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp description do
    """
    The application-wide registry with handy helpers to ease dispatching.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|config lib mix.exs README.md|,
      source_ref: "v#{@version}",
      source_url: "https://github.com/#{@owner}/#{@app}",
      canonical: "http://hexdocs.pm/#{@app}",
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/#{@owner}/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "Gelato",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48x48.png",
      source_url: "https://github.com/#{@owner}/#{@app}",
      # extras: [
      #   "stuff/#{@app_name}.md",
      #   "stuff/backends.md"
      # ],
      groups_for_modules: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
