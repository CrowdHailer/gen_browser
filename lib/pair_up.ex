defmodule PairUp do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(%{"pair_me" => address}, nil) do
    {:noreply, address}
  end

  def handle_info(%{"pair_me" => address}, address) do
    {:noreply, address}
  end

  def handle_info(%{"pair_me" => address2}, address1) do
    GenBrowser.send_message(address1, %{"your_pair" => address2})
    GenBrowser.send_message(address2, %{"your_pair" => address1})
    {:noreply, nil}
  end
end
