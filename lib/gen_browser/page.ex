defmodule GenBrowser.Page do
  use GenServer

  def start_link(page_id) do
    GenServer.start_link(__MODULE__, {page_id}, name: {:global, {__MODULE__, page_id}})
  end

  def init({page_id}) do
    {:ok, %{page_id: page_id, connection: nil}}
  end

  def handle_call({:connection, connection}, _from, state) do
    {:reply, :ok, %{state | connection: connection}}
  end

  def handle_info(anything, state) do
    send(state.connection, anything)
    {:noreply, state}
  end
end
