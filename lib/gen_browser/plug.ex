defmodule GenBrowser.Plug do
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
      {mailbox_id, cursor} <- decode_last_event_id(conn)

      messages <- GenBrowser.Mailbox.read(mailbox_id, cursor, GenBrowser.MailboxSupervisor, %{})
    after
      first_chunk = Enum.map(messages, &GenBrowser.Web.encode_message(&1, [conn.secret_key_base]))

      {:ok, conn} =
        conn
        |> put_resp_header("content-type", @sse_mime_type)
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_chunked(200)
        |> chunk(first_chunk)

      loop(conn)
    rescue
      reason ->
        # TODO error pages
        raise inspect(reason)
    end
  end

  def call(conn = %{method: "POST", path_info: [namespace, "send", secured]}, %{
        namespace: namespace
      }) do
    OK.try do
      address <- GenBrowser.Web.unwrap_secure(secured, [conn.secret_key_base])
      address <- GenBrowser.Address.decode(address)
      _ <- GenBrowser.Address.send_message(address, conn.body_params)
    after
      conn
      |> put_resp_header("access-control-allow-origin", "*")
      |> resp(202, "")
      |> halt()
    rescue
      reason ->
        # TODO error pages
        raise inspect(reason)
    end
  end

  def call(conn = %{method: "OPTIONS", path_info: [namespace, "send", secured]}, %{
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

      other ->
        IO.inspect(other)
        loop(conn)
        # TODO needs to handle down
    after
      300_000 ->
        conn
    end
  end

  defp decode_last_event_id(conn) do
    GenBrowser.Web.decode_last_event_id(
      List.first(Plug.Conn.get_req_header(conn, "last-event-id")),
      [
        conn.secret_key_base
      ]
    )
  end
end
