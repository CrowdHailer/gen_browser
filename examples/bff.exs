defmodule BFF.PairUp do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(%{"pair_me" => address}, nil) do
    {:noreply, address}
  end

  def handle_info(%{"pair_me" => address}, address) do
    {:noreply, address}
  end

  def handle_info(%{"pair_me" => address2}, address1) do
    {:ok, address1} = GenBrowser.Address.decode(address1)
    {:ok, address2} = GenBrowser.Address.decode(address2)
    IO.inspect("Paired up '#{inspect(address1)}' with '#{inspect(address2)}'")
    GenBrowser.Address.send_message(address1, %{"your_pair" => address2})
    GenBrowser.Address.send_message(address2, %{"your_pair" => address1})
    {:noreply, nil}
  end
end

BFF.PairUp.start_link()

content = File.read!(Path.join(__DIR__, "bff.html"))

client_config = %{"pair_up" => GenBrowser.Address.new(BFF.PairUp)}

GenBrowser.Standalone.start_link(client_config,
  page_content: content,
  port: 8080,
  cleartext: true
)
