defmodule HoneylixirTracing.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

  def project do
    [
      app: :honeylixir_tracing,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:honeylixir, ">= 0.5.0"}
    ]
  end
end
