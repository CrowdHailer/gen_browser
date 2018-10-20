# GenBrowser

**Transparent bi-directional communication for clients, servers and more**

## Example

```js
// ponger.html
const client = await GenBrowser.start('http://localhost:8080')

console.log(client.address)

client.mailbox.setHandler((message) => {
  console.log('received message:', message)
  client.send(message.caller, {type: 'pong'})
})
```

```js
// pinger.html
const client = await GenBrowser.start('http://localhost:8080')

const peer = prompt("Enter a ponger address.")
client.send(peer, {type: 'ping', caller: client.address})

await client.mailbox.receive({timeout: 5000})
console.log("Pong received")
```
```js
// Global is an address which can be used to globally register names
const { global } = config

send(registry, {register: 'alice', address: mailbox.address})


// Can decode the address in the final process
send(registry, {lookup: 'alice', reply: mailbox.address})
```

Once started `gen-browser` has four things.

1. An address that other clients, or the server, use it to send messages to this browser.
2. A mailbox to receive messages. The mailbox can be used in one of two ways, but not both.
  - `mailbox.receive()` will return a promise that will resolve on the next message received by the browser.
  - `mailbox.handle(callback)` will call the callback with the contents of a message each time one is received.
3. A function to send messages, that takes the target address and messages as arguments.
  The message must be serialisable to JSON.
4. Config from the server, this can be anything including addresses for processes on the backend,
  such as the global registry process in the examples above.

*Note:* Receive cannot be called on mailbox that has a custom handler installed.

## Playground

The pinger/ponger example is included in the `/examples` dir this project.
Clone this repo and follow the instructions below to experiment.

```
git clone git@github.com:CrowdHailer/gen_browser.git
cd gen_browser
```

Make sure the JavaScript bundle is built.

```
npm install
npm run build
```

To start the backend use Docker as follows.

```
docker build -t gen-browser . && docker run -it -p 8080:8080 gen-browser
```

Or, if you have Elixir installed but not docker, mix can be used directly

```
mix run --no-halt examples/standalone.exs
```

Look for help with JS API docs


## Server API

GenBrowser.start_link(config)

## Roadmap

### Pinger/ponder example

- Registry should accept a ping message
- Ping to the console
- Ping to some other browser

could add logger to standard setup

### Integration with raxx and/or plug

Document server API

### Secure the addresses using signatures

A client should only be able to send message to addresses it has been provided with.
i.e. it should not be possible to guess the address of processes.

This is the Object capability security model https://en.wikipedia.org/wiki/Object-capability_model

To do this the server should sign addresses, and verify signatures before forwarding the message.

By signing the event-id this method can be used to secure an individual clients reconnections

### Demonstrate with Redux

This could just be the redux swarm below.
There are ways to start new browser windows, this might be fun

### Clear the server mailbox

Client should be able to send the ability to ack messages and clear up the contents of the server mailbox.

The server mailbox process should also have a timeout after which a reconnection is not possible.

Can the id of a reconnect be taken as an ack, or should that be sent separatly.

There should also be a timeout after which the mailbox process dies.
Finally we need to signal to the client in cases when a reconnect to a dead mailbox is attempted.

`Clients will reconnect if the connection is closed; a client can be told to stop reconnecting using the HTTP 204 No Content response code.`
This might not trigger an onerror, it might be best to on error on the client so sending a 4xx could be better

### Work out how to provide a validation layer for messages as they are received by server

`send` already returns a promise, awaiting on this could at least validate message was legit

### Redux middleware

This is the comms goal, i.e. don't call send, just return a list of addresses and messages thus making the whole thing pure.

## Notes

### Whats in a name?

The name `GenBrowser` comes from the erlang/Elixir terms for generalised servers; `GenServer`.
Originally this project was aiming to model interations with the browser the same as any other erlang process.
However at this point it is clear this is just a general communication layer and does not need to be tied to any erlang/OTP terminology.

Other names
// cloud sounds like backup. instead redux-swarm, redux-flock, redux-cluster, redux-comms
// conveyance, transmission,

### Redux is the JavaScript name for Actor

Redux doesn't have a way to spawn new processes, so the analogy is not perfect.
However it is probably the closed many developers have come.
This might be a useful place to start the conversation.

### `EventSource` is not implemented in IE

Polyfills are available and some of these work in a node environment.

### There is no alert for disconnects

The browser disconnecting from the internet might not be important.
Messages for the browser will be kept on the server until it reconnects.
Because this is a distributed system, being connected to the server might still not mean you are connected to the peer you need.

To check connections send a message and await a reply or timeout.

If it is necessary to check connection with the server in general a message can be sent from the browser to it's own address.
This will involve a server round trip.

### Clients are temporary

### Messages not understood

Messages can always not be understood by the server.
When using `send` the response is 202 accepted, this just means the server in general was happy the target process might not know how to handle the message.

The target process might not even know who the message came from, and so be unable to return an error.
In this case the system has to rely on timeouts and crashlogging.

To tackle this problem a standard message container could be provided,
it might include a standard format for sender, and perhaps tracing.
Such a standard format could easily be built on top of this library.

### GenCall

A call function could exist, both where the server can call the client and block on response and vica versa.

This would require the send function to have a reference to the mailbox.
It would also require a selective receive, other push messages from the server might have arrived.
A standard call format would go someway to providing a standard message container as discussed in messages not understood.

### Security

TODO signature
- If id generation secure enough don't need to sign those addresses,
  However will always need to sign encoded tuples, don't want those to be generated
- Reconnection id is the security mechanism to act as someone.
  In what cases does that id get sent again? How can nefarious actors get to that information,
  EventSource doesn't let you add custom headers.

### Redux swarm where you send every browser you are connected to

### Single language

This project aims to unify the programming model accross both client and server.
It does not yet unify language.
The goal to unify language would be an argument for a server implemented in node, however this is not the best host for thinging of the system using the Actor model.
It might be possible to use ElixirScript for the front end.

---

blob about unified but not liveview

// Would be good if i could get an address I can call on

### Rational

Client/Server is just another type of distributed system.
What if the whole system can be treated as a group of processes that send messages to each other.

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
