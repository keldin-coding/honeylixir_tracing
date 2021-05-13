defmodule HoneylixirTracing.Integrations.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias HoneylixirTracing.Context
  alias HoneylixirTracing.Integrations.Plug

  setup do
    start_supervised!(HoneylixirTracing.Integrations.PlugTracker)
    start_supervised!(HoneylixirTestListener)

    c =
      conn(:get, "https://foobar.com/great/stuff")
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    %{conn: c}
  end

  describe "call/2" do
    test "starts a span with all the extracted information", %{conn: conn} do
      Plug.call(conn, nil)

      span = Context.current_span()
      refute is_nil(span)

      fields = span.event.fields

      assert %{
               "request.method" => "GET",
               "request.http_version" => :"HTTP/1.1",
               "request.scheme" => :https,
               "request.port" => 443,
               "request.host" => "foobar.com",
               "request.path" => "/great/stuff",
               "request.header.accept" => "application/json",
               "request.header.content_type" => "application/json",
               "request.header.accept_encoding" => nil,
               "name" => "http_request"
             } = fields
    end

    test "register the process with the PlugTracker", %{conn: conn} do
      conn = Plug.call(conn, nil)

      span = Context.current_span()
      refute is_nil(span)

      monitor_ref = conn.assigns[:plug_tracker_ref]
      span_key = {span.trace_id, span.span_id}

      assert %{^monitor_ref => ^span_key} =
               :sys.get_state(HoneylixirTracing.Integrations.PlugTracker)
    end

    test "adds response fields when sent", %{conn: conn} do
      conn =
        conn
        |> Plug.call(nil)
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("content-length", "10")
        |> send_resp(200, "abcdefghij")

      assert is_nil(Context.current_span())

      refute Map.has_key?(
               :sys.get_state(HoneylixirTracing.Integrations.PlugTracker),
               conn.assigns.plug_tracker_ref
             )

      [sent_event] = HoneylixirTestListener.values()

      assert %{
               "response.status_code" => "200",
               "response.header.content_type" => "application/json",
               "response.header.content_length" => 10
             } = sent_event.fields
    end
  end
end
