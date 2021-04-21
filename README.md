# HoneylixirTracing

[![CircleCI](https://circleci.com/gh/lirossarvet/honeylixir_tracing.svg?style=shield)](https://circleci.com/gh/lirossarvet/honeylixir_tracing)

Note: This project is in no way officially affiliated with Honeycomb. This work is my own.

VERY MUCH A WORK IN PROGRESS

Hoping to provide similar ease of use, installation, etc... as other Honeycomb beelines for tracing data. The OTel BEAM libs work and are great and fine, I just miss that thrill of joy of installing a Ruby gem, setting a couple configs, and getting traces through so much. It was delightful and I wanted to try and see if I could bring that to people.

Currently this builds on my own [Honeylixir libhoney-esque library](https://github.com/lirossarvet/honeylixir), but could (eventually?) use OTel under the hood or allow configurability. At the moment, though, since this is purely personal, I'm focused on integrating with my own and an eye to maaaaaaybe using OTel concepts.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `honeylixir_tracing` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honeylixir_tracing, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/honeylixir_tracing](https://hexdocs.pm/honeylixir_tracing).
