defmodule HoneylixirTracing.MixProject do
  use Mix.Project

  @source_url "https://github.com/lirossarvet/honeylixir_tracing"
  @version "0.1.0-dev"

  def project do
    [
      app: :honeylixir_tracing,
      version: @version,
      elixir: "~> 1.11",
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
      {:honeylixir, path: "../honeylixir"}
    ]
  end

  defp docs() do
    [
      main: Honeylixir.Tracing,
      source_url: @source_url
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
