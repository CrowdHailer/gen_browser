defmodule MyLogger do
  use GenServer
  require Logger

  def start_link(secrets) do
    GenServer.start_link(__MODULE__, secrets, name: __MODULE__)
  end

  def init(secrets) do
    {:ok, secrets}
  end

  def handle_info(%{"type" => "ping", "from" => secured_address}, secrets) do
    {:ok, string_address} = GenBrowser.Web.unwrap_secure(secured_address, secrets)
    {:ok, address} = GenBrowser.Address.decode(string_address)
    Logger.info("Ping received from '#{inspect(address)}'")

    {:ok, _} =
      GenBrowser.Address.send_message(address, %{
        "type" => "pong",
        "from" => GenBrowser.Address.new(__MODULE__)
      })

    {:noreply, secrets}
  end

  def handle_info(message, state) do
    Logger.warn("unexpected message #{inspect(message)}")
    {:noreply, state}
  end
end

secrets = ["not_secret_at_all"]
MyLogger.start_link(secrets)

Ace.HTTP.Service.start_link(
  {GenBrowser.Raxx, %{secrets: secrets, config: %{logger: GenBrowser.Address.new(MyLogger)}}},
  port: 8080,
  cleartext: true
)
