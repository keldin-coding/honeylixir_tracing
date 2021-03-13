import Config

config :honeylixir,
  service_name: "honeylixir-tests",
  datetime_module: Honeylixir.DateTimeFake,
  api_host: "https://api.honeycomb.io"
