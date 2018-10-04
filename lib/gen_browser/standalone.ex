defmodule GenBrowser.Standalone do
  use Raxx.Server

  javascript_path = File.read!(Path.join(__DIR__, "page.js"))
  @external_resource javascript_path
  @javascript_response response(:ok)
                       |> set_header("content-type", "applicaton/javascript")
                       |> set_body(javascript_path)

  def start_link(page_state, options) do
    page_content = Keyword.get(options, :page_content, "NOT FOUND")
    page_content_type = Keyword.get(options, :page_content_type, "text/html")

    server_options = Keyword.take(options, [:cleartext, :port])

    page =
      response(:ok)
      |> set_header("content-type", page_content_type)
      |> set_body(page_content)

    Ace.HTTP.Service.start_link(
      {__MODULE__, %{page: page, page_state: page_state}},
      server_options
    )
  end

  def handle_request(request = %{method: :GET, path: ["_gen_browser", "page.js"]}, _config) do
    @javascript_response
  end

  def handle_request(request = %{method: :GET, path: ["_gen_browser", "mailbox"]}, state) do
    "text/event-stream" = Raxx.get_header(request, "accept")
    # nil = Raxx.get_header(request, "last-event-id")
    page_id = GenBrowser.Page.generate_id()
    page_address = GenBrowser.Page.address(page_id)

    # Can use Dynamic Supervisor if global gives use the correct already started behaviour
    {:ok, pid} =
      Supervisor.start_child(GenBrowser.Page.Supervisor, %{
        id: page_id,
        start: {GenBrowser.Page, :start_link, [page_id]}
      })

    GenServer.call(pid, {:connection, self})

    setup =
      Jason.encode!(%{
        "id" => page_id,
        "address" => GenBrowser.Address.new(page_address),
        "config" => state.page_state
      })

    setup_event = ServerSentEvent.serialize(setup, id: "#{page_id}:0", type: "gen_browser")

    response =
      response(:ok)
      |> set_header("content-type", ServerSentEvent.mime_type())
      |> set_header("access-control-allow-origin", "*")
      |> set_body(true)

    {[response, Raxx.data(setup_event)], state}
  end

  def handle_request(request = %{method: :POST, path: ["_gen_browser", "send", address]}, config) do
    # TODO check signature
    {:ok, address} = GenBrowser.Address.decode(address)
    # TODO better decoding
    message = Jason.decode!(request.body)
    GenBrowser.Address.send_message(address, message)

    response(:accepted)
  end

  # TODO serve on all pages
  def handle_request(%{method: :GET, path: []}, config) do
    config.page
  end

  def handle_request(%{path: _}, config) do
    response(:not_found)
  end

  def handle_info(message, state) do
    data = Raxx.data(ServerSentEvent.serialize(Jason.encode!(message)))
    {[data], state}
  end
end
