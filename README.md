# GenBrowser

**Treat a client like any other Elixir/erlang process in a distributed system**

## Rational

Client/Server is just another type of distributed system.
What if the whole system is treated as a group of processes that send messages to each other.

Currently it is easy to send messages client to server.
The goal of this project is to make it just as easy to send messages client to server and even client to client.

#### So experimental right now

Best thing to do is play with examples. Docs are available below but in a state of flux.

Check the [Roadmap](#Roadmap) for what I'm working on next.

#### Is this crazy?

Maybe.

Let me know what you think.

## Examples

- clone this repo
- pull dependencies `mix deps.get`
- start the example, see example.
- visit `localhost:8080`

### Contrary

*start the example:* `mix run examples/contrary.exs`

Send messages from client to server and back.

### BFF

*start the example:* `mix run examples/bff.exs`

Send messages from client to another client.

## Docs

### Starting the backend

```elixir
GenServer.start_link(SomeModule, state, name: SomeModule)

# The initial client state.
# once initialized clients will be able to send messages directly to the GenServer called `SomeModule`
client_state = %{"named_process" => SomeModule}

# The page that is going to be playing the role of a process in our system.
page_content = File.read!(Path.join(__DIR__, "my_page.html"))

GenBrowser.Standalone.start_link(client_config,
  page_content: content,
  port: 8080,
  cleartext: true
)
```

*The roadmap includes making it possible to mount the backend in a Raxx or Plug/Phoenix application as well as running a singlepage in standalone fashion.*

## GenBrowser client API

Include the gen_browser JavaScript by including the following script tag in the page content.

```html
<script type="text/javascript" src="/_gen_browser/page.js"></script>
```

This adds `GenBrowser` to the JavaScript environment.

```js
var client = new GenBrowser({
  init: function(state){
    console.log('Page started', state)
    return state
  },
  handle_info: function(message, state){
    console.log('Message received', message)
    return state
  }
})
```

A GenBrowser client has to implement two callbacks.

- `init` called when first connected.
  The argument to this function is the client config the backent was started with.
  This should contain the reference to at least one process, normally a named process.
  For security reasons the client cannot generate it's own process references but must be given them by the server.

- `handle_info` called for every message sent to the browser.

Once connected the client can be used to send messages to any process (client or server) that it knows about.
These messages can contain references to any pid the client knows about, including itself.

```js
client.send(client.state.named_process, {text: 'anything', from: client.address})
```

## Roadmap

- Add CORS headers so that client does not need to be served from the same host
- Add Docker wrapped example service for JavaScript developers
- Handle reconnects
  - Needs to buffer messages when client is not connected
  - Needs to read last-event-id and resume forwarding
  - (Later) needs to ack message to clear buffer
- Put client JavaScript on npm
- Be able to use GenBrowser within other web projects
  - Raxx
  - Plug/Phoenix
- Redux middleware integration
- Parsing received messages to structs somehow.
- Ack message to reduce the size of the mailbox.
  - prevent reconnecting to some event that has previously been acked.
    `Clients will reconnect if the connection is closed; a client can be told to stop reconnecting using the HTTP 204 No Content response code.`
    This might not trigger an onerror, it might be best to on error on the client so sending a 4xx could be better
- Check signatures
- Extend to iOS and Android, maybe a better name is GenClient.
- Configure reconnect timeout.
- Kill page process if no reconnect before timeout.
- use PUT vs POST for retries
- Work out what to do if page process dies.
  Probably this should be propogated to client, that then restarts or refreshes page. This would be the way to manage deployment and state lives in other processes.
- ElixirScript

## Security
- If id generation secure enough don't need to sign those addresses,
  However will always need to sign encoded tuples, don't want those to be generated
- Reconnection id is the security mechanism to act as someone.
  In what cases does that id get sent again? How can nefarious actors get to that information,
  EventSource doesn't let you add custom headers.

### OldExamples, Check out https://github.com/CrowdHailer/gen_browser/commit/06c27106a5a3c44988155d9f4e305cab823ad8c5

```js
GenBrowser.send(client.address, {text: 'Talking to myself'})
// > {text: "Talking to myself"}
```

You should see the message written into the browser console

### Talk to a back end process.

```js
GenBrowser.send(client.state.logger, {text: 'Talking to the server'})
```

in the iex shell you should see
```elixir
"I got this message, %{\"text\" => \"Talking to the server\"}"
```

### Send a message from the server

Fetch the address of the client page,
```js
client.address
// > "g2gCZAAGZ2xvYmFsaAJkABZFbGl4aXIuR2VuQnJvd3Nlci5QYWdlbQAAAAY2ODA3MzQ="
```

Use this address to send a message to that page

```elixir
GenBrowser.send_message("g2gCZAAGZ2xvYmFsaAJkABZFbGl4aXIuR2VuQnJvd3Nlci5QYWdlbQAAAAY2ODA3MzQ=", %{text: "Hello from the server"})
```

Again it should be visible in the browser console.

### Talk to another browser

There is a named process on the server that will pair up processes that talk to it.
this will require two browser consoles.

```js
// console 1
GenBrowser.send(client.state.pair_up, {pair_me: client.address})
```
```js
// console 2
GenBrowser.send(client.state.pair_up, {pair_me: client.address})
```

After both have sent a pair_up message you should see the following logged
```
paired with g2gCZAAGZ2xvYmFsaAJkABZFbGl4aXIuR2VuQnJvd3Nlci5QYWdlbQAAAAYwNTUwNjU=
```

And the pair will be written to the window object

```js
// console 1
GenBrowser.send(client.state.pair, {text: 'Hello from another browser'})
```

This message will have been delivered to browser 2
```js
// console 2
//{text: 'Hello from another browser'}
```
