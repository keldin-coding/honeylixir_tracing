# HoneylixirTracing

[![CircleCI](https://circleci.com/gh/lirossarvet/honeylixir_tracing.svg?style=shield)](https://circleci.com/gh/lirossarvet/honeylixir_tracing)

For complete documentation, including installation and usage, check the [published docs](https://hexdocs.pm/honeylixir_tracing).

## Introduction

Hoping to provide similar ease of use, installation, etc... as other Honeycomb beelines for tracing data. The OTel BEAM libs work and are great and fine, I just miss that thrill of joy of installing a Ruby gem, setting a couple configs, and getting traces through so much. It was delightful and I wanted to try and see if I could bring that to people.

Currently this builds on my own [Honeylixir libhoney-esque library](https://github.com/lirossarvet/honeylixir),
but could (eventually?) use OTel under the hood or allow configurability. At the moment,
though, since this is purely personal, I'm focused on integrating with my own for my own usage
and education. That said! You should absolutely feel free to give it a shot and use it.
Feedback is always welcome, as are pull requests.

## Unwritten Features

There's probably a lot missing, but one important one is the ability to set Trace fields. These are fields that would be set on all future child spans once they're added.
