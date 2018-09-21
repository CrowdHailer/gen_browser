defmodule GenBrowser do
  def send_message(address, message) when is_binary(address) do
    {:ok, address} = decode_address(address)
    send_message(address, message)
  end

  def send_message(address, message) do
    # TODO function clause guards
    case address do
      address when is_atom(address) ->
        :erlang.whereis(address)

      {:global, term} ->
        :global.whereis_name(term)
    end
    |> IO.inspect()
    |> send(message)
  end

  defp encode_address(address) do
    Base.url_encode64(:erlang.term_to_binary(address))
  end

  def decode_address(binary) do
    case Base.url_decode64(binary) do
      {:ok, binary} ->
        case :erlang.binary_to_term(binary) do
          term ->
            {:ok, term}
        end
    end
  end
end
