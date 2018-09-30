defmodule GenBrowser.Address do
  @enforce_keys [:value]
  defstruct @enforce_keys

  def new(value) do
    %__MODULE__{value: value}
  end

  @doc """
  Encode an address to a string, that can be sent to a clinet.
  """
  def encode(%__MODULE__{value: value}) do
    Base.url_encode64(:erlang.term_to_binary(value))
  end

  @doc """
  Decode a client safe address
  """
  def decode(string) do
    case Base.url_decode64(string) do
      {:ok, string} ->
        case :erlang.binary_to_term(string) do
          term ->
            {:ok, new(term)}
        end
    end
  end

  def send_message(address, message) do
    # TODO check whereis returns a pid
    send(whereis(address), message)
  end

  @doc """
  Find the pid for an address,

  Note this is mostly just recreating the lookup inside GenServer.call
  """
  def whereis(%__MODULE__{value: value}) do
    case value do
      value when is_atom(value) ->
        :erlang.whereis(value)

      {:global, term} ->
        :global.whereis_name(term)
    end
  end
end

defimpl Jason.Encoder, for: GenBrowser.Address do
  def encode(address, _options) do
    "\"#{GenBrowser.Address.encode(address)}\""
  end
end
