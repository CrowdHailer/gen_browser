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
    IO.inspect(reason)
    {:stop, :normal, test_pid}
  end

  def handle_disconnect(reason, test_pid) do
    IO.inspect(reason)
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

defmodule GenBrowser.RaxxTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, server} =
      Ace.HTTP.Service.start_link({GenBrowser.Raxx, :config}, port: 0, cleartext: true)

    {:ok, port} = Ace.HTTP.Service.port(server)
    {:ok, port: port}
  end

  test "Check that reconnect works", %{port: port} do
    request =
      Raxx.request(:GET, "http://localhost:#{port}/mailbox")
      |> Raxx.set_header("accept", ServerSentEvent.mime_type())

    ServerSentEvent.Client.start_link(Forwarder, {self(), request})

    assert_receive %{id: cursor0, lines: [json]}

    assert {:ok, %{"address" => address, "config" => config, "type" => "__gen_browser__/init"}} =
             Jason.decode(json)

    request =
      Raxx.request(:POST, "http://localhost:#{port}/send/#{address}")
      |> Raxx.set_body(Jason.encode!(%{ping: 1}))

    Raxx.SimpleClient.send_sync(request, 2000)

    request =
      Raxx.request(:POST, "http://localhost:#{port}/send/#{address}")
      |> Raxx.set_body(Jason.encode!(%{ping: 2}))

    Raxx.SimpleClient.send_sync(request, 2000)

    assert_receive %{id: cursor1, lines: ["{\"ping\":1}"]}
    assert_receive %{id: cursor2, lines: ["{\"ping\":2}"]}

    request =
      Raxx.request(:GET, "http://localhost:#{port}/mailbox")
      |> Raxx.set_header("accept", ServerSentEvent.mime_type())
      |> Raxx.set_header("last-event-id", cursor0)

    ServerSentEvent.Client.start_link(Forwarder, {self(), request})

    assert_receive %{id: ^cursor1, lines: ["{\"ping\":1}"]}
    assert_receive %{id: ^cursor2, lines: ["{\"ping\":2}"]}

    refute_receive _

    request =
      Raxx.request(:GET, "http://localhost:#{port}/mailbox")
      |> Raxx.set_header("accept", ServerSentEvent.mime_type())
      |> Raxx.set_header("last-event-id", cursor1)

    ServerSentEvent.Client.start_link(Forwarder, {self(), request})

    assert_receive %{id: ^cursor2, lines: ["{\"ping\":2}"]}

    refute_receive _
  end

  # Reading from an already dead process does not restart it
end
