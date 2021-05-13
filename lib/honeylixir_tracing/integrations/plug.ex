if Code.ensure_loaded?(Plug.Conn) do
  defmodule HoneylixirTracing.Integrations.Plug do
    @moduledoc """
    A `Plug` meant to be inserted into the pipeline for wrapping a request in a span.

    ## Examples

        defmodule SampleApp.Endpoint do
          use Phoenix.Endpoint, otp_app: :sample_app

          @session_options [
            store: :cookie,
            key: "_sample_app_key",
            signing_salt: "YouOKaKr"
          ]

          plug HoneylixirTracing.Integrations.Plug
          plug Plug.RequestId
          plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

          # ... the rest of your plugs
        end
    """

    import HoneylixirTracing
    import Plug.Conn
    alias HoneylixirTracing.{Propagation, Context}
    alias HoneylixirTracing.Integrations.PlugTracker

    def init(opts), do: opts

    def call(conn, _opts) do
      %{
        method: http_method,
        # version: http_version,
        scheme: scheme,
        host: host,
        port: port,
        request_path: path
      } = conn

      prop =
        extract_req_header(conn, "x-honeycomb-trace")
        |> Propagation.parse_header()

      accept = extract_req_header(conn, "accept")
      content_type = extract_req_header(conn, "content-type")
      accept_encoding = extract_req_header(conn, "accept-encoding")

      fields = %{
        "request.method" => http_method,
        "request.http_version" => get_http_protocol(conn),
        "request.scheme" => scheme,
        "request.port" => port,
        "request.host" => host,
        "request.path" => path,
        "request.header.accept" => accept,
        "request.header.accept_encoding" => accept_encoding,
        "request.header.content_type" => content_type
      }

      {:ok, previous_span} = start_span(prop, "http_request", fields)
      current = Context.current_span()

      monitor_ref = PlugTracker.register(self(), {current.trace_id, current.span_id})

      conn
      |> assign(:plug_tracker_ref, monitor_ref)
      |> register_before_send(fn bs_conn ->
        %{status: status} = bs_conn

        content_length =
          with length when is_binary(length) <- extract_resp_header(bs_conn, "content-length"),
               {length, _rest} <- Integer.parse(length) do
            length
          else
            _ -> nil
          end

        content_type = extract_resp_header(bs_conn, "content-type")

        add_field_data(%{
          "response.status_code" => to_string(status),
          "response.header.content_type" => content_type,
          "response.header.content_length" => content_length
        })

        end_span(previous_span)
        PlugTracker.finalize(bs_conn.assigns.plug_tracker_ref)
        bs_conn
      end)
    end

    defp extract_req_header(conn, key) do
      case get_req_header(conn, key) do
        [value] ->
          value

        _ ->
          nil
      end
    end

    defp extract_resp_header(conn, key) do
      case get_resp_header(conn, key) do
        [value] ->
          value

        _ ->
          nil
      end
    end
  end
end
