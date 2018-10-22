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
        GenBrowser.Mailbox.read(mailbox_id, cursor, GenBrowser.MailboxSupervisor, state.config)
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

  def encode(message, secrets) do
    GenBrowser.Web.encode_message(message, secrets)
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

  defp decode_last_event_id(request, secrets) do
    case GenBrowser.Web.decode_last_event_id(get_header(request, "last-event-id"), secrets) do
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
