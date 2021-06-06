defmodule HoneylixirTracing.MixProject do
  use Mix.Project

  @source_url "https://github.com/lirossarvet/honeylixir_tracing"
  @version "0.4.0"

  def project do
    [
      app: :honeylixir_tracing,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      elixirc_paths: compiler_paths(Mix.env()),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {HoneylixirTracing.Application, []},
      extra_applications: [:logger],
      included_application: [:honeylixir]
    ]
  end

  defp deps do
    [
      {:honeylixir, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:plug, ">= 1.9.0", optional: true},
      # this is pulled in by honeylixir technically, but it seems good to declare
      # it here since we use it for some integrations.
      {:telemetry, ">= 0.4.0", optional: true}
    ]
  end

  defp docs() do
    [
      main: HoneylixirTracing,
      source_url: @source_url,
      extras: ["CHANGELOG.md", "INTEGRATIONS.md"]
    ]
  end

  defp description() do
    "Library providing tracing capabilities in Elixir for Honeycomb"
  end

  defp compiler_paths(_), do: ["lib"]

  defp package() do
    [
      name: "honeylixir_tracing",
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end
end
