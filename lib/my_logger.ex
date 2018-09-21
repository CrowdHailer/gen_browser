defmodule MyLogger do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_info(some_message, state) do
    IO.inspect("I got this message, #{inspect(some_message)}")
    {:noreply, state}
  end
end
