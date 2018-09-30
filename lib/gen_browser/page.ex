defmodule GenBrowser.Page do
  use GenServer

  def start_link(page_id) do
    GenServer.start_link(__MODULE__, {page_id}, name: address(page_id))
  end

  def address(page_id) do
    {:global, {__MODULE__, page_id}}
  end

  def generate_id() do
    safe_random_string(12)
  end

  defp safe_random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
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
