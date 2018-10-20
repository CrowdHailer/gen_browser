defmodule GenBrowser.Raxx do
  use Raxx.Server
  use Raxx.Logger

  @impl Raxx.Server
  def handle_request(request = %{path: ["mailbox"]}, state) do
    # ok/error accept header
    # ok/error verify last-event-id return nil
    # Mailbox.read(address, cursor) ok/error
    {:ok, messages} =
      case Raxx.get_header(request, "last-event-id") do
        nil ->
          GenBrowser.Mailbox.read(nil, nil, GenBrowser.MailboxSupervisor, %{foo: 5})

        last_event_id ->
          [page_id, string_cursor] = String.split(last_event_id, ":")
          {cursor, ""} = Integer.parse(string_cursor)
          GenBrowser.Mailbox.read(page_id, cursor, GenBrowser.MailboxSupervisor, %{foo: 5})
      end

    response =
      response(:ok)
      |> set_header("content-type", ServerSentEvent.mime_type())
      |> set_header("access-control-allow-origin", "*")
      |> set_body(true)

    {[response | Enum.map(messages, &encode/1)], state}
  end

  def handle_request(request = %{method: :POST, path: ["send", address]}, _state) do
    {:ok, address} = GenBrowser.Address.decode(address)
    message = Jason.decode!(request.body)
    GenBrowser.Address.send_message(address, message)
    response(:accepted)
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
end
