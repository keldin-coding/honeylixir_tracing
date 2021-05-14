defmodule HoneylixirTracing.Integrations.Ecto do
  @moduledoc """
  Integration for instrumenting and adding spans for Ecto queries.
  """

  @doc """
  Sets up the :telemetry attachment for getting Ecto spans.

  This will be called for you on application startup if application config is provided.
  """
  def setup(config) do
    repo_name = Keyword.get(config, :repo_name)
    prefix = Keyword.get(config, :event_prefix)

    if is_nil(repo_name) && is_nil(prefix) do
      raise """
      You must provide either repo_name or event_prefix to the setup call.
      event_prefix will take precedence if given with repo_name. If only repo_name
      is given, it is assumed the event_prefix is [<repo_name>, :repo]
      """
    end

    event_name = if prefix, do: prefix ++ [:query], else: [repo_name, :repo, :query]

    :telemetry.attach(
      {__MODULE__, event_name},
      event_name,
      &handle_ecto_event/4,
      nil
    )
  end

  @doc false
  def handle_ecto_event(
        _,
        %{total_time: total_time} = measurements,
        %{query: query, repo: repo, type: type, source: source},
        _config
      ) do
    start_time = System.monotonic_time() - total_time
    # timestamp = DateTime.from_unix!(:erlang.system_time() - total_time, :native)

    fields = %{
      "db.ecto.queue_time_ms" => native_to_ms(Map.get(measurements, :queue_time)),
      "db.ecto.query_time_ms" => native_to_ms(Map.get(measurements, :query_time)),
      "db.ecto.decode_time_ms" => native_to_ms(Map.get(measurements, :decode_time)),
      "db.ecto.total_time_ms" => native_to_ms(total_time),
      "db.database_name" => repo.config()[:database],
      "db.ecto.source" => source,
      "db.statement" => query
    }

    span = HoneylixirTracing.Span.setup(to_string(type), fields)
    # %{span.event | timestamp: DateTime.to_iso8601(timestamp)}
    event = span.event
    span = %{span | event: event, start_time: start_time}

    HoneylixirTracing.Span.send(span)
  end

  defp native_to_ms(nil), do: nil

  defp native_to_ms(nativetime) do
    System.convert_time_unit(nativetime, :native, :microsecond) / 1000
  end
end
