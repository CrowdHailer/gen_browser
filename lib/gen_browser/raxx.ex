defmodule GenBrowser.Raxx do
  use Raxx.Server
  use Raxx.Logger

  require OK

  @sse_mime_type ServerSentEvent.mime_type()

  @impl Raxx.Server
  def handle_request(request = %{path: ["mailbox"]}, state) do
    OK.try do
      _ <- verify_accepts_server_sent_events(request)
      {mailbox_id, cursor} <- decode_last_event_id(request, state.secrets)

      messages <-
        GenBrowser.Mailbox.read(mailbox_id, cursor, GenBrowser.MailboxSupervisor, %{foo: 5})
    after
      response_head =
        response(:ok)
        |> set_header("content-type", @sse_mime_type)
        |> set_header("access-control-allow-origin", "*")
        |> set_body(true)

      {[response_head | Enum.map(messages, &encode(&1, state.secrets))], state}
    rescue
      response = %Raxx.Response{} ->
        response

      :no_mailbox_process ->
        response(:no_content)
        |> set_header("access-control-allow-origin", "*")
    end
  end

  def handle_request(request = %{method: :POST, path: ["send", address]}, state) do
    OK.try do
      address <- unwrap_address(address, state.secrets)
      address <- decode_address(address)
      message <- decode_message(request)
      _ <- send_message(address, message)
    after
      response(:accepted)
    rescue
      response = %Raxx.Response{} ->
        response
    end
    |> set_header("access-control-allow-origin", "*")
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {[Raxx.tail([])], state}
  end

  def handle_info(update, state) do
    {[encode(update, state.secrets)], state}
  end

  def encode(%{id: id, data: data, type: :init}, secrets) do
    data = Map.merge(data, %{type: "__gen_browser__/init"})
    wrapped_data = wrap_all_addresses(data, secrets)

    ServerSentEvent.serialize(
      Jason.encode!(wrapped_data),
      id: GenBrowser.Web.wrap_secure(id, secrets)
    )
    |> Raxx.data()
  end

  def encode(%{id: id, data: data}, secrets) do
    data = wrap_all_addresses(data, secrets)

    ServerSentEvent.serialize(Jason.encode!(data), id: GenBrowser.Web.wrap_secure(id, secrets))
    |> Raxx.data()
  end

  defp wrap_all_addresses(address = %GenBrowser.Address{}, secrets) do
    GenBrowser.Web.wrap_secure(GenBrowser.Address.encode(address), secrets)
  end

  defp wrap_all_addresses(data = %_struct{}, _secrets) do
    # leave as is assume they can handle protocols
    data
  end

  defp wrap_all_addresses(map = %{}, secrets) do
    Enum.map(map, fn {key, value} -> {key, wrap_all_addresses(value, secrets)} end)
    |> Enum.into(%{})
  end

  defp wrap_all_addresses(list = [], secrets) do
    Enum.map(list, fn value -> wrap_all_addresses(value, secrets) end)
  end

  defp wrap_all_addresses(other, _secrets) do
    other
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

  defp decode_last_event_id(request, secrets) do
    invalid_format_message =
      "Reconnection failed to due incorrect format of 'last-event-id' header"

    case get_header(request, "last-event-id") do
      nil ->
        {:ok, {nil, nil}}

      last_event_id ->
        case GenBrowser.Web.unwrap_secure(last_event_id, secrets) do
          {:ok, reconnect_id} ->
            case String.split(reconnect_id, ":") do
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

          _ ->
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

  defp unwrap_address(secured, secrets) do
    case GenBrowser.Web.unwrap_secure(secured, secrets) do
      {:ok, address} ->
        {:ok, address}

      {:error, reason} ->
        {:error,
         response(:bad_request) |> set_body("Could not decode address for reason '#{reason}'")}
    end
  end

  defp decode_address(string) do
    case GenBrowser.Address.decode(string) do
      {:ok, address} ->
        {:ok, address}

      {:error, reason} ->
        {:error,
         response(:bad_request) |> set_body("Could not decode address for reason '#{reason}'")}
    end
  end

  defp decode_message(%{body: body}) do
    # NOTE could check content type
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, data}

      _ ->
        {:error,
         response(:bad_request)
         |> set_body("Could not decode message, must be valid JSON")}
    end
  end

  def send_message(address, message) do
    case GenBrowser.Address.send_message(address, message) do
      {:ok, value} ->
        {:ok, value}

      {:error, :dead} ->
        {:error,
         response(:gone)
         |> set_body("Could not resolve address")}
    end
  end
end
