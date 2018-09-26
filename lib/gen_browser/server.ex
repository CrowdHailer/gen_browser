defmodule GenBrowser.Server do
  use Ace.HTTP.Service, cleartext: true, port: 8080
  use Raxx.View
  alias ServerSentEvent, as: SSE

  def handle_request(%{method: :GET, path: []}, state) do
    response(:ok)
    |> render()
  end

  def handle_request(%{method: :GET, path: ["favicon.ico"]}, state) do
    response(:ok)
  end

  def handle_request(request = %{method: :GET, path: ["mailbox"]}, state) do
    page_id = String.pad_leading("#{:rand.uniform(1_000_000) - 1}", 6, "0")
    page_address = GenBrowser.Page.address(page_id)

    # Can use Dynamic Supervisor if global gives use the correct already started behaviour
    {:ok, pid} =
      Supervisor.start_child(GenBrowser.Page.Supervisor, %{
        id: page_id,
        start: {GenBrowser.Page, :start_link, [page_id]}
      })

    GenServer.call(pid, {:connection, self})

    # TODO make the result of init
    setup =
      Jason.encode!(%{
        "id" => page_id,
        "address" => encode_address(page_address),
        "config" => %{"logger" => encode_address(MyLogger), "pair_up" => encode_address(PairUp)}
      })

    setup_event = SSE.serialize(setup, id: "#{page_id}:0", type: "gen_browser")

    # :global.register_name({HelloBrowser.Session, id}, self)

    response =
      response(:ok)
      |> set_header("content-type", ServerSentEvent.mime_type())
      |> set_body(true)

    # Process.send_after(self(), {:data, setup_event}, 2000)
    {[response, Raxx.data(setup_event)], state}
  end

  def handle_request(%{method: :POST, path: ["mailbox", address], body: body}, state) do
    {:ok, address} = decode_address(address)
    message = Jason.decode!(body)

    case address do
      address when is_atom(address) ->
        :erlang.whereis(address)

      {:global, term} ->
        :global.whereis_name(term)
    end
    |> IO.inspect()
    |> send(message)

    response(:created)
  end

  def handle_info(message, state) do
    data = Raxx.data(SSE.serialize(Jason.encode!(message)))
    {[data], state}
  end

  defp encode_address(address) do
    Base.url_encode64(:erlang.term_to_binary(address))
  end

  def decode_address(binary) do
    case Base.url_decode64(binary) do
      {:ok, binary} ->
        case :erlang.binary_to_term(binary) do
          term ->
            {:ok, term}
        end
    end
  end
end
