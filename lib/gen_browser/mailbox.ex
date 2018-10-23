defmodule GenBrowser.Mailbox do
  @moduledoc false
  use GenServer

  def read(nil, nil, supervisor, config) do
    mailbox_id = generate_id()
    address = {:global, {__MODULE__, mailbox_id}}

    started =
      DynamicSupervisor.start_child(supervisor, %{
        id: :no_op,
        start: {__MODULE__, :start_link, [address]},
        restart: :temporary
      })

    case started do
      {:ok, pid} ->
        address = GenBrowser.Address.new(address)
        _ref = Process.monitor(pid)
        :ok = GenServer.call(pid, {:read, 0, self()})

        {:ok,
         [
           %GenBrowser.Message{
             id: {mailbox_id, 0},
             data: %{address: address, config: config, type: "__gen_browser__/init"}
           }
         ]}
    end
  end

  def read(mailbox_id, cursor, _supervisor, _config) do
    case :global.whereis_name({__MODULE__, mailbox_id}) do
      pid when is_pid(pid) ->
        :ok = GenServer.call(pid, {:read, cursor, self()})
        # Could send messages and just return ref instead here
        _ref = Process.monitor(pid)

        {:ok, []}

      :undefined ->
        {:error, :no_mailbox_process}
    end
  end

  @doc false
  def start_link(address) do
    {:global, {__MODULE__, mailbox_id}} = address
    # Need to monitor connections
    GenServer.start_link(__MODULE__, %{backlog: [], clients: %{}, mailbox_id: mailbox_id},
      name: address
    )
  end

  @impl GenServer
  def init(args) do
    {:ok, args}
  end

  @impl GenServer
  def handle_call({:read, cursor, client}, _from, state) do
    {_sent, to_send} = Enum.split(state.backlog, cursor)
    ref = Process.monitor(client)
    Enum.each(to_send, &send(client, &1))
    state = %{state | clients: Map.put(state.clients, ref, client)}
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, pid, _reason}, state = %{clients: clients}) do
    {^pid, clients} = Map.pop(clients, ref)
    {:noreply, %{state | clients: clients}}
  end

  def handle_info(message, state = %{backlog: backlog}) do
    event = %GenBrowser.Message{id: {state.mailbox_id, length(backlog) + 1}, data: message}
    Enum.each(state.clients, fn {_ref, pid} -> send(pid, event) end)
    {:noreply, %{state | backlog: backlog ++ [event]}}
  end

  defp generate_id() do
    safe_random_string(12)
  end

  defp safe_random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end
end
