defmodule HoneylixirTracing.Integrations.EctoTest do
  use ExUnit.Case, async: true
  alias HoneylixirTracing.Integrations.Ecto, as: EctoIntegration

  describe "setup/1" do
    test "rejects setup with no repo_name or event_prefix" do
      assert_raise RuntimeError, ~r/You must provide either repo_name or event_prefix/, fn ->
        EctoIntegration.setup([])
      end
    end

    test "accepts repo_name" do
      EctoIntegration.setup(repo_name: :amazing)

      handlers = :telemetry.list_handlers([:amazing, :repo, :query])

      assert Enum.any?(handlers, fn h ->
               h[:id] == {HoneylixirTracing.Integrations.Ecto, [:amazing, :repo, :query]} &&
                 h[:event_name] == [:amazing, :repo, :query]
             end)

      :ok = :telemetry.detach({HoneylixirTracing.Integrations.Ecto, [:amazing, :repo, :query]})
    end

    test "accepts event_prefix" do
      EctoIntegration.setup(event_prefix: [:cool, :time])

      handlers = :telemetry.list_handlers([:cool, :time, :query])

      assert Enum.any?(handlers, fn h ->
               h[:id] == {HoneylixirTracing.Integrations.Ecto, [:cool, :time, :query]} &&
                 h[:event_name] == [:cool, :time, :query]
             end)

      :ok = :telemetry.detach({HoneylixirTracing.Integrations.Ecto, [:cool, :time, :query]})
    end

    test "given event_prefix overrides repo_name" do
      EctoIntegration.setup(event_prefix: [:cool, :time], repo_name: :whatever)

      handlers = :telemetry.list_handlers([:cool, :time, :query])

      assert Enum.any?(handlers, fn h ->
               h[:id] == {HoneylixirTracing.Integrations.Ecto, [:cool, :time, :query]} &&
                 h[:event_name] == [:cool, :time, :query]
             end)

      :ok = :telemetry.detach({HoneylixirTracing.Integrations.Ecto, [:cool, :time, :query]})
    end
  end

  describe "handle_ecto_event/4" do
    test "sets the timestamp appropriately" do
      start_supervised!(HoneylixirTestListener)

      EctoIntegration.handle_ecto_event(
        nil,
        %{total_time: 100_000, query_time: 100, decode_time: 100},
        %{
          query: "SELECT * FROM users",
          repo: HoneylixirTestStubbedRepo,
          type: :ecto_sql,
          source: "User"
        },
        nil
      )

      [event] = HoneylixirTestListener.values()

      test_ts =
        with {:ok, parsed_ts, _} <- DateTime.from_iso8601(event.timestamp) do
          DateTime.to_unix(parsed_ts, :microsecond)
        end

      current = :erlang.system_time(:microsecond)

      # Just assert the test timestamp is far behind and not super close.
      # Could probably get smarter if we stub DateTime module but this seems Fine.
      assert current - test_ts >= 50_000
    end

    test "pull in timing and metadata" do
      start_supervised!(HoneylixirTestListener)

      EctoIntegration.handle_ecto_event(
        nil,
        %{total_time: 100_000, query_time: 100, decode_time: 100},
        %{
          query: "SELECT * FROM users",
          repo: HoneylixirTestStubbedRepo,
          type: :ecto_sql,
          source: "User"
        },
        nil
      )

      [event] = HoneylixirTestListener.values()

      assert %{
               "db.ecto.queue_time_ms" => nil,
               "db.ecto.query_time_ms" => query_time,
               "db.ecto.decode_time_ms" => decode_time,
               "db.ecto.total_time_ms" => total_time,
               "db.database_name" => "whatever_dev",
               "db.ecto.source" => "User",
               "db.statement" => "SELECT * FROM users"
             } = event.fields

      assert query_time == System.convert_time_unit(100, :native, :microsecond) / 1000
      assert decode_time == System.convert_time_unit(100, :native, :microsecond) / 1000
      assert total_time == System.convert_time_unit(100_000, :native, :microsecond) / 1000
    end
  end
end
