if Code.ensure_compiled?(Plug) do
  defmodule GenBrowser.Plug do
    @moduledoc """
    Start a GenBrowser backend within a Plug application.

    **NOTE** this plug expects the body to have been parsed.
    """

    @behaviour Plug
    import Plug.Conn

    require OK

    @sse_mime_type ServerSentEvent.mime_type()

    def init(options) do
      namespace = Keyword.get(options, :namespace, "_gb")
      %{namespace: namespace}
    end

    def call(conn = %{method: "GET", path_info: [namespace, "mailbox"]}, %{namespace: namespace}) do
      OK.try do
        _ <- verify_accepts_server_sent_events(conn)
        {mailbox_id, cursor} <- decode_last_event_id(conn)

        messages <- GenBrowser.Mailbox.read(mailbox_id, cursor, GenBrowser.MailboxSupervisor, %{})
      after
        first_chunk =
          Enum.map(messages, &GenBrowser.Web.encode_message(&1, [conn.secret_key_base]))

        {:ok, conn} =
          conn
          |> put_resp_header("content-type", @sse_mime_type)
          |> put_resp_header("access-control-allow-origin", "*")
          |> send_chunked(200)
          |> chunk(first_chunk)

        loop(conn)
      rescue
        conn = %Plug.Conn{} ->
          Plug.Conn.halt(conn)

        :no_mailbox_process ->
          conn
          |> resp(:no_content, "")
          |> put_resp_header("access-control-allow-origin", "*")
          |> halt()
      end
    end

    def call(conn = %{method: "POST", path_info: [namespace, "send", secured]}, %{
          namespace: namespace
        }) do
      OK.try do
        address <- decode_address(secured, conn)
        message <- decode_message(conn)
        _ <- send_message(address, message, conn)
      after
        conn
        |> put_resp_header("access-control-allow-origin", "*")
        |> resp(202, "")
        |> halt()
      rescue
        conn = %Plug.Conn{} ->
          conn
          |> put_resp_header("access-control-allow-origin", "*")
          |> Plug.Conn.halt()
      end
    end

    def call(conn = %{method: "OPTIONS", path_info: [namespace, "send", _secured]}, %{
          namespace: namespace
        }) do
      conn
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("access-control-allow-headers", "content-type")
      |> resp(:ok, "CORS TIME")
      |> halt()
    end

    def call(conn, _) do
      conn
    end

    defp loop(conn) do
      receive do
        update = %{data: _data, id: _id} ->
          data = GenBrowser.Web.encode_message(update, [conn.secret_key_base])
          {:ok, conn} = chunk(conn, data)

          loop(conn)

        # NOTE this catches all downs, might be good to add ref to conn state
        {:DOWN, _ref, :process, _pid, _reason} ->
          conn
          |> halt()

        {:plug_conn, :sent} ->
          loop(conn)
      after
        300_000 ->
          conn
      end
    end

    defp verify_accepts_server_sent_events(conn) do
      case Plug.Conn.get_req_header(conn, "accept") do
        [@sse_mime_type] ->
          {:ok, @sse_mime_type}

        [] ->
          message = "Request did not send any 'accept' header, expected `#{@sse_mime_type}`"
          {:error, Plug.Conn.resp(conn, :not_acceptable, message)}

        [_other] ->
          message = "Request did not send correct 'accept' header, expected `#{@sse_mime_type}`"
          {:error, Plug.Conn.resp(conn, :not_acceptable, message)}
      end
    end

    defp decode_last_event_id(conn) do
      header = List.first(Plug.Conn.get_req_header(conn, "last-event-id"))

      case GenBrowser.Web.decode_last_event_id(header, [conn.secret_key_base]) do
        {:ok, value} ->
          {:ok, value}

        {:error, message} ->
          {:error, resp(conn, :forbidden, message)}
      end
    end

    defp decode_address(secured_address, conn = %Plug.Conn{}) do
      OK.try do
        string_address <- GenBrowser.Web.unwrap_secure(secured_address, [conn.secret_key_base])
        address <- GenBrowser.Address.decode(string_address)
      after
        {:ok, address}
      rescue
        reason ->
          {:error, resp(conn, :bad_request, "Could not decode address for reason '#{reason}'")}
      end
    end

    defp decode_message(conn = %Plug.Conn{body_params: body_params}) do
      case body_params do
        %Plug.Conn.Unfetched{aspect: :body_params} ->
          conn =
            conn
            |> resp(:bad_request, "Could not decode message, must be valid JSON")

          {:error, conn}

        data ->
          {:ok, data}
      end
    end

    def send_message(address, message, conn) do
      case GenBrowser.Address.send_message(address, message) do
        {:ok, value} ->
          {:ok, value}

        {:error, :dead} ->
          {:error, Plug.Conn.resp(conn, :gone, "Could not resolve address")}
      end
    end
  end
end
