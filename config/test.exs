import Config

config :honeylixir,
  dataset: "honeylixir-test",
  service_name: "honeylixir-tests",
  datetime_module: DateTimeFake,
  transmission_queue: HoneylixirTestListener,
  api_host: "https://api.honeycomb.io"

config :honeylixir_tracing,
  _start_reaper: false,
  span_ttl_sec: 1
