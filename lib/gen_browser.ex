defmodule GenBrowser do
  require OK

  @doc """
  Start a new backend for the GenBrowser clients.

  First argument is the configuration that clients will receive when started.
  This communal must be JSON encodable.
  All addresses are sent to the client must be wrapped as a `GenBrowser.Address` struct,
  This will ensure they are signed to protect against tampering.

  If the secrets option is not set the value will be read from environment variable SECRET
  """
  def start_link(communal, options) do
    {secrets, server_options} = Keyword.pop(options, :secrets, [System.get_env("SECRET")])

    Ace.HTTP.Service.start_link(
      {GenBrowser.Raxx, %{secrets: secrets, communal: communal}},
      server_options
    )
  end

  @doc """
  Encode any term and sign against tampering

  If secrets is not set will look for value in SECRET environment variable
  """
  def encode_address(term, secrets \\ [System.get_env("SECRET")]) do
    target = GenBrowser.Address.encode(GenBrowser.Address.new(term))
    GenBrowser.Web.wrap_secure(target, secrets)
  end

  @doc """
  Validate signature and decode binary representation of an address

  If secrets is not set will look for value in SECRET environment variable
  """
  # NOTE address_binary consists of target and signature
  def decode_address(secure_binary, secrets \\ [System.get_env("SECRET")]) do
    OK.for do
      target <- GenBrowser.Web.unwrap_secure(secure_binary, secrets)
      term <- GenBrowser.Address.decode(target)
    after
      term.value
    end
  end

  @doc """
  Send message to a decoded address
  """
  def send(term, message) do
    GenBrowser.Address.send_message(GenBrowser.Address.new(term), message)
  end
end
