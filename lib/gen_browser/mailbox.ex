# mailbox instead of page
# action send to mailbox
# subscribe to mailbox - take empty id for new
# The address is the struct, validating signatures should happen at the controller level
# coupling shadow mirror
# archive depo

# If server mailbox has died need to return no content to stop retries
# This is seen as requesting later than

defmodule GenBrowser.Mailbox do
  use GenServer

  def read(nil, nil, supervisor, config) do
    page_id = generate_id()
    address = {:global, {__MODULE__, page_id}}

    started =
      DynamicSupervisor.start_child(supervisor, %{
        id: :no_op,
        start: {__MODULE__, :start_link, [address]}
      })

    case started do
      {:ok, pid} ->
        address = GenBrowser.Address.new(address)
        :ok = GenServer.call(pid, {:read, 0, self})
        {:ok, [%{id: "#{page_id}:0", data: %{address: address, config: config}, type: :init}]}
    end
  end

  # mailbox_id
  def read(page_id, cursor, supervisor, config) do
    pid = :global.whereis_name({__MODULE__, page_id})
    :ok = GenServer.call(pid, {:read, cursor, self})
    {:ok, []}
  end

  @doc false
  def start_link(address) do
    {:global, {__MODULE__, page_id}} = address
    # Need to monitor connections
    GenServer.start_link(__MODULE__, %{backlog: [], pids: [], page_id: page_id}, name: address)
  end

  def handle_call({:read, cursor, caller}, _from, state) do
    {_sent, to_send} = Enum.split(state.backlog, cursor)

    Enum.each(to_send, &send(caller, &1))
    state = %{state | pids: [caller | state.pids]}
    {:reply, :ok, state}
  end

  def handle_info(message, state = %{backlog: backlog}) do
    id = "#{state.page_id}:#{length(backlog) + 1}"
    event = %{id: id, data: message}
    Enum.each(state.pids, &send(&1, event))
    {:noreply, %{state | backlog: backlog ++ [event]}}
  end

  defp generate_id() do
    safe_random_string(12)
  end

  defp safe_random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end
end

defmodule GenBrowser.Raxx do
  use Raxx.Server
  # use Raxx.Logger

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

  def handle_request(request = %{method: :POST, path: ["send", address]}, state) do
    {:ok, address} = GenBrowser.Address.decode(address)
    message = Jason.decode!(request.body)
    GenBrowser.Address.send_message(address, message)
    response(:accepted)
  end

  def handle_info(update, state) do
    {[encode(update)], state}
  end

  def encode(%{id: id, data: data, type: :init}) do
    ServerSentEvent.serialize(Jason.encode!(data), type: "__gen_browser__/init", id: id)
    |> Raxx.data()
  end

  def encode(%{id: id, data: data}) do
    ServerSentEvent.serialize(Jason.encode!(data), id: id)
    |> Raxx.data()
  end
end

defmodule GenBrowser.Web do
  def decode_cursor(last_event_id, security) do
  end

  def decode_cursor(nil, _security) do
    {:ok, {nil, nil}}
  end
end
