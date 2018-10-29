defmodule GenBrowser.Web do
  {:ok, javascript} = File.read(Path.join(__DIR__, "../../client/dist/gen_browser.js"))

  @external_resource "dist/gen-browser.js"
  def javascript_content() do
    unquote(javascript)
  end

  @moduledoc false
  def decode_last_event_id(last_event_id, secrets) do
    invalid_format_message =
      "Reconnection failed to due incorrect format of 'last-event-id' header"

    case last_event_id do
      nil ->
        {:ok, {nil, nil}}

      last_event_id ->
        case unwrap_secure(last_event_id, secrets) do
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
  end

  def encode_message(%GenBrowser.Message{id: {mailbox_id, cursor}, data: data}, secrets) do
    id = wrap_secure("#{mailbox_id}:#{cursor}", secrets)
    data = Jason.encode!(wrap_all_addresses(data, secrets))

    ServerSentEvent.serialize(data, id: id)
  end

  defp wrap_all_addresses(address = %GenBrowser.Address{}, secrets) do
    wrap_secure(GenBrowser.Address.encode(address), secrets)
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

  def wrap_secure(data, [secret | _previous_secrets]) do
    # Expects data to already be safe, i.e. no "--"
    digest = safe_digest(data, secret)
    data <> "--" <> digest
  end

  def unwrap_secure(payload, secrets) do
    case String.split(payload, "--", parts: 2) do
      [data, digest] ->
        if verify_signature(data, digest, secrets) do
          {:ok, data}
        else
          {:error, :invalid_signature}
        end

      _ ->
        {:error, :invalid_signing_format}
    end
  end

  defp safe_digest(payload, secret) do
    :crypto.hmac(:sha256, secret, payload)
    |> Base.url_encode64()
  end

  defp verify_signature(payload, digest, secrets) do
    Enum.any?(secrets, fn secret ->
      secure_compare(digest, safe_digest(payload, secret))
    end)
  end

  defp secure_compare(left, right) do
    if byte_size(left) == byte_size(right) do
      secure_compare(left, right, 0) == 0
    else
      false
    end
  end

  defp secure_compare(<<x, left::binary>>, <<y, right::binary>>, acc) do
    import Bitwise
    xorred = x ^^^ y
    secure_compare(left, right, acc ||| xorred)
  end

  defp secure_compare(<<>>, <<>>, acc) do
    acc
  end
end
