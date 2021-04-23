import Config

config :honeylixir,
  dataset: "honeylixir-test",
  service_name: "honeylixir-tests",
  datetime_module: DateTimeFake,
  transmission_queue: HoneylixirTestListener,
  api_host: "https://api.honeycomb.io"
