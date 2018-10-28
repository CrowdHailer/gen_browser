defmodule Playground.Logger do
  use GenServer
  require Logger
  require OK

  def start_link(secrets) do
    GenServer.start_link(__MODULE__, secrets, name: __MODULE__)
  end

  def init(secrets) do
    {:ok, secrets}
  end

  def handle_info(%{"type" => "ping", "from" => secured_address}, secrets) do
    OK.try do
      string_address <- GenBrowser.Web.unwrap_secure(secured_address, secrets)
      address <- GenBrowser.Address.decode(string_address)
    after
      Logger.info("Ping received from '#{inspect(address)}'")

      {:ok, _} =
        GenBrowser.Address.send_message(address, %{
          "type" => "pong",
          "from" => GenBrowser.Address.new(__MODULE__)
        })

      {:noreply, secrets}
    rescue
      error ->
        Logger.warn("Bad message, #{inspect(error)}")
        {:noreply, secrets}
    end
  end

  def handle_info(%{"type" => "log", "text" => text}, secrets) when is_binary(text) do
    Logger.info(text)
    {:noreply, secrets}
  end

  def handle_info(message, state) do
    Logger.warn("unexpected message #{inspect(message)}")
    {:noreply, state}
  end
end

defmodule Playground.Global do
  use GenServer
  require Logger
  require OK
  defstruct [:names, :secrets]

  def start_link(secrets) do
    GenServer.start_link(__MODULE__, secrets, name: __MODULE__)
  end

  def init(secrets) do
    {:ok, %__MODULE__{secrets: secrets, names: %{}}}
  end

  def handle_info(%{"type" => "register", "name" => name, "address" => secured_address}, state) do
    OK.try do
      string_address <- GenBrowser.Web.unwrap_secure(secured_address, state.secrets)
      address <- GenBrowser.Address.decode(string_address)
    after
      names = Map.put(state.names, name, address)
      Logger.debug("#{name} registered to address #{inspect(address)}")
      {:noreply, %{state | names: names}}
    rescue
      error ->
        Logger.warn("Bad message, #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_info(%{"type" => "lookup", "name" => name, "from" => secured_address}, state) do
    OK.try do
      string_address <- GenBrowser.Web.unwrap_secure(secured_address, state.secrets)
      from <- GenBrowser.Address.decode(string_address)
    after
      case Map.fetch(state.names, name) do
        {:ok, found} ->
          Logger.debug("Lookup for #{name} succeded")

          GenBrowser.Address.send_message(from, %{
            "type" => "found",
            "name" => name,
            "address" => GenBrowser.Address.new(found)
          })

        :error ->
          Logger.debug("Lookup for #{name} failed")

          GenBrowser.Address.send_message(from, %{
            "type" => "notFound",
            "name" => name
          })
      end

      {:noreply, state}
    rescue
      error ->
        Logger.warn("Bad message, #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_info(message, state) do
    Logger.warn("unexpected message #{inspect(message)}")
    {:noreply, state}
  end
end

secrets =
  case System.get_env("SECRET") do
    nil ->
      raise "Need to set a secret"

    secret ->
      [secret]
  end

Playground.Logger.start_link(secrets)
Playground.Global.start_link(secrets)

GenBrowser.start_link(
  %{
    logger: GenBrowser.Address.new(Playground.Logger),
    global: GenBrowser.Address.new(Playground.Global)
  },
  secrets: secrets,
  port: 8080,
  cleartext: true
)
