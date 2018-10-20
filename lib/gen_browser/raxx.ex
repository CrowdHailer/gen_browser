defmodule GenBrowser.Raxx do
  use Raxx.Server
  use Raxx.Logger

  require OK

  @sse_mime_type ServerSentEvent.mime_type()

  @impl Raxx.Server
  def handle_request(request = %{path: ["mailbox"]}, state) do
    OK.try do
      _ <- verify_accepts_server_sent_events(request)
      {mailbox_id, cursor} <- decode_last_event_id(request)

      messages <-
        GenBrowser.Mailbox.read(mailbox_id, cursor, GenBrowser.MailboxSupervisor, %{foo: 5})
    after
      response_head =
        response(:ok)
        |> set_header("content-type", @sse_mime_type)
        |> set_header("access-control-allow-origin", "*")
        |> set_body(true)

      {[response_head | Enum.map(messages, &encode/1)], state}
    rescue
      response = %Raxx.Response{} ->
        response

      :no_mailbox_process ->
        response(:no_content)
        |> set_header("access-control-allow-origin", "*")
    end
  end

  def handle_request(request = %{method: :POST, path: ["send", address]}, _state) do
    {:ok, address} = GenBrowser.Address.decode(address)
    message = Jason.decode!(request.body)
    GenBrowser.Address.send_message(address, message)
    response(:accepted)
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {[Raxx.tail([])], state}
  end

  def handle_info(update, state) do
    {[encode(update)], state}
  end

  def encode(%{id: id, data: data, type: :init}) do
    ServerSentEvent.serialize(Jason.encode!(Map.merge(data, %{type: "__gen_browser__/init"})),
      id: id
    )
    |> Raxx.data()
  end

  def encode(%{id: id, data: data}) do
    ServerSentEvent.serialize(Jason.encode!(data), id: id)
    |> Raxx.data()
  end

  defp verify_accepts_server_sent_events(request) do
    case get_header(request, "accept") do
      @sse_mime_type ->
        {:ok, @sse_mime_type}

      nil ->
        message = "Request did not send any 'accept' header, expected `#{@sse_mime_type}`"

        response =
          response(:not_acceptable)
          |> set_body(message)

        {:error, response}

      _other ->
        message = "Request did not send correct 'accept' header, expected `#{@sse_mime_type}`"

        response =
          response(:not_acceptable)
          |> set_body(message)

        {:error, response}
    end
  end

  defp decode_last_event_id(request) do
    invalid_format_message =
      "Reconnection failed to due incorrect format of 'last-event-id' header"

    case get_header(request, "last-event-id") do
      nil ->
        {:ok, {nil, nil}}

      last_event_id ->
        case String.split(last_event_id, ":") do
          [mailbox_id, string_cursor] ->
            case Integer.parse(string_cursor) do
              {cursor, ""} ->
                {:ok, {mailbox_id, cursor}}

              _ ->
                {:error, invalid_format_message}
            end

          _other ->
            {:error, invalid_format_message}
        end
    end
    |> case do
      {:ok, value} ->
        {:ok, value}

      {:error, message} ->
        {:error, response(:forbidden) |> set_body(message)}
    end
  end
end
