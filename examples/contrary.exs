defmodule Contrary.Flipper do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_info(%{"text" => text, "sender" => sender}, state) when is_binary(text) do
    reversed = String.reverse(text)
    IO.inspect("I got this message '#{text}', and sent this message '#{reversed}'.")

    {:ok, sender} = GenBrowser.Address.decode(sender)
    GenBrowser.Address.send_message(sender, %{"text" => reversed})
    {:noreply, state}
  end
end

Contrary.Flipper.start_link()

content = File.read!(Path.join(__DIR__, "contrary.html"))

client_config = %{"flipper" => GenBrowser.Address.new(Contrary.Flipper)}

GenBrowser.Standalone.start_link(client_config,
  page_content: content,
  port: 8080,
  cleartext: true
)
