defmodule GenBrowser.Web do
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
