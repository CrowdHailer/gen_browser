defmodule Forwarder do
  @behaviour ServerSentEvent.Client

  def init({test_pid, request}) do
    {:connect, request, test_pid}
  end

  def handle_connect(_response, test_pid) do
    {:noreply, test_pid}
  end

  # Retry connecting to endpoint 1 second after a failure to connect.
  def handle_connect_failure(reason, test_pid) do
    send(test_pid, {:connect_failure, reason})
    {:stop, :normal, test_pid}
  end

  def handle_disconnect(reason, test_pid) do
    send(test_pid, {:disconnect, reason})
    {:stop, :normal, test_pid}
  end

  def handle_info(message, test_pid) do
    IO.inspect(message)
    {:noreply, test_pid}
  end

  def handle_event(event, test_pid) do
    send(test_pid, event)
    test_pid
  end
end

defmodule GenBrowser.TestPlug do
  use Plug.Builder

  plug(:put_secret_key_base)

  def put_secret_key_base(conn, _) do
    put_in(conn.secret_key_base, "secret")
  end

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(GenBrowser.Plug)

  plug(:fallback)

  def fallback(conn, _) do
    resp(conn, 404, "Fallback")
  end
end

defmodule GenBrowser.IntegrationTest do
  use ExUnit.Case, async: true

  @sse_mime_type ServerSentEvent.mime_type()

  setup_all do
    Plug.Cowboy.http(GenBrowser.TestPlug, [], port: 4444)
    {:ok, plug: 4444}
  end

  setup do
    {:ok, server} =
      Ace.HTTP.Service.start_link({GenBrowser.Raxx, %{secrets: ["secret"], config: %{}}},
        port: 0,
        cleartext: true
      )

    {:ok, port} = Ace.HTTP.Service.port(server)
    {:ok, raxx: port}
  end

  test "Check that reconnect works", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      # for 1. plug 2. raxx simply Log which one. should be alright
      # Rename web test
      # Comment in vs article that this is how the tests work
      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", ServerSentEvent.mime_type())

      ServerSentEvent.Client.start_link(Forwarder, {self(), request})

      assert_receive %{id: cursor0, lines: [json]}

      assert {:ok, %{"address" => address, "config" => config, "type" => "__gen_browser__/init"}} =
               Jason.decode(json)

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{ping: 1}))

      Raxx.SimpleClient.send_sync(request, 2000)

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{ping: 2}))

      Raxx.SimpleClient.send_sync(request, 2000)

      assert_receive %{id: cursor1, lines: ["{\"ping\":1}"]}
      assert_receive %{id: cursor2, lines: ["{\"ping\":2}"]}

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", ServerSentEvent.mime_type())
        |> Raxx.set_header("last-event-id", cursor0)

      ServerSentEvent.Client.start_link(Forwarder, {self(), request})

      assert_receive %{id: ^cursor1, lines: ["{\"ping\":1}"]}
      assert_receive %{id: ^cursor2, lines: ["{\"ping\":2}"]}

      refute_receive _

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", ServerSentEvent.mime_type())
        |> Raxx.set_header("last-event-id", cursor1)

      ServerSentEvent.Client.start_link(Forwarder, {self(), request})

      assert_receive %{id: ^cursor2, lines: ["{\"ping\":2}"]}

      refute_receive _
    end
  end

  test "Mailbox endpoint expects accept header", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      request = Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 406
    end
  end

  test "Mailbox endpoint expects accept header to be for server sent events", %{
    raxx: raxx,
    plug: plug
  } do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", "text/plain")

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 406
    end
  end

  test "Invalid format for reconnect id is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      last_event_id = GenBrowser.Web.wrap_secure("not_at_all_valid", ["secret"])

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)
        |> Raxx.set_header("last-event-id", last_event_id)

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 403

      last_event_id = GenBrowser.Web.wrap_secure("ok:but_still_not_a_number", ["secret"])

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)
        |> Raxx.set_header("last-event-id", last_event_id)

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 403

      last_event_id = "foo--signature"

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)
        |> Raxx.set_header("last-event-id", last_event_id)

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 403

      last_event_id = "not_even_a_signature"

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)
        |> Raxx.set_header("last-event-id", last_event_id)

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 403
    end
  end

  test "When mailbox process dies the event stream connection is closed permanently", %{
    raxx: raxx,
    plug: plug
  } do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)

      ServerSentEvent.Client.start_link(Forwarder, {self(), request})

      assert_receive %{id: cursor0, lines: [json]}
      [mailbox_id, _] = String.split(cursor0, ":")
      pid = :global.whereis_name({GenBrowser.Mailbox, mailbox_id})
      :ok = GenServer.stop(pid)
      assert_receive {:disconnect, _reason}

      request = request |> Raxx.set_header("last-event-id", cursor0)
      ServerSentEvent.Client.start_link(Forwarder, {self(), request})
      # NOTE 204 is not really a bad response in case of SSE event stream
      assert_receive {:connect_failure, {:bad_response, %{status: 204}}}

      assert :undefined == :global.whereis_name({GenBrowser.Mailbox, mailbox_id})
    end
  end

  test "When a connection to the client is lost it is removed from mailbox", %{
    raxx: raxx,
    plug: plug
  } do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      request =
        Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
        |> Raxx.set_header("accept", @sse_mime_type)

      {:ok, client} = ServerSentEvent.Client.start_link(Forwarder, {self(), request})

      assert_receive %{id: cursor0, lines: [json]}
      [mailbox_id, _] = String.split(cursor0, ":")

      mailbox = :global.whereis_name({GenBrowser.Mailbox, mailbox_id})

      assert 1 = Enum.count(:sys.get_state(mailbox).clients)
      GenServer.stop(client)
      Process.sleep(100)
      assert 0 = Enum.count(:sys.get_state(mailbox).clients)
    end
  end

  # describe "Sending messages to an address" do
  # setup %{raxx: raxx, plug: plug} do
  #   for {name, port} <- [raxx: raxx, plug: plug] do
  #     IO.inspect("TESTING #{name}")
  #   end
  #
  #   request =
  #     Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
  #     |> Raxx.set_header("accept", ServerSentEvent.mime_type())
  #
  #   ServerSentEvent.Client.start_link(Forwarder, {self(), request})
  #
  #   assert_receive %{id: cursor0, lines: [json]}
  #
  #   assert {:ok, %{"address" => address}} = Jason.decode(json)
  #
  #   {:ok, address: address}
  # end

  defp get_address(port) do
    request =
      Raxx.request(:GET, "http://localhost:#{port}/_gb/mailbox")
      |> Raxx.set_header("accept", ServerSentEvent.mime_type())

    ServerSentEvent.Client.start_link(Forwarder, {self(), request})

    assert_receive %{id: cursor0, lines: [json]}

    assert {:ok, %{"address" => address}} = Jason.decode(json)

    {address, cursor0}
  end

  test "content that cannot be understood is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")
      {address, _} = get_address(port)

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "something/random")
        |> Raxx.set_body("NOT JSON")

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 400
    end
  end

  @tag :skip
  # Plug parsers raise an error if cannot pass so we get a 500 response
  test "invalid JSON is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")
      {address, _} = get_address(port)

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body("NOT JSON")

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      IO.inspect(response)
      assert response.status == 400
    end
  end

  test "address that is not base64 encoded is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      address = "==="
      address = GenBrowser.Web.wrap_secure(address, ["secret"])

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{}))

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 400
    end
  end

  test "address that is not a valid term is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      address = Base.url_encode64("===")
      address = GenBrowser.Web.wrap_secure(address, ["secret"])

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{}))

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 400
    end
  end

  test "address that has incorrect signature is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      address = "abc--signature"

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{}))

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 400
    end
  end

  test "address that has no signature is rejected", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")

      address = "not_even_a_signature"

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{}))

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 400
    end
  end

  test "which is no longer alive is handled", %{raxx: raxx, plug: plug} do
    for {name, port} <- [raxx: raxx, plug: plug] do
      IO.inspect("TESTING #{name}")
      {address, _} = get_address(port)

      request =
        Raxx.request(:POST, "http://localhost:#{port}/_gb/send/#{address}")
        |> Raxx.set_header("content-type", "application/json")
        |> Raxx.set_body(Jason.encode!(%{}))

      {:ok, address} = GenBrowser.Web.unwrap_secure(address, ["secret"])
      {:ok, address_struct} = GenBrowser.Address.decode(address)
      pid = GenBrowser.Address.whereis(address_struct)
      :ok = GenServer.stop(pid)

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2000)
      assert response.status == 410
    end
  end
end
