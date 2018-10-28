# GenBrowser

**Transparent bi-directional communication for clients, servers and more**

 GenBrowser gives every client a unique identifier that can be used to send messages to/from/between clients AND server processes.

## Example

To experiment with a similar example follow the instructions to set up the [Playground](#playground).

```js
// ponger.html
const client = await GenBrowser.start('http://localhost:8080')

console.log(client.address)

client.mailbox.setHandler((message) => {
  console.log('received message:', message)
  client.send(message.from, {type: 'pong'})
})
```

```js
// pinger.html
const client = await GenBrowser.start('http://localhost:8080')

var peer = prompt("Enter a ponger address.")
if (peer == '') {
  peer = client.communal.logger
}
client.send(peer, {type: 'ping', from: client.address})

await client.mailbox.receive({timeout: 5000})
console.log("Pong received")
```

Once started `gen-browser` has four things.

1. An address that other clients, or the server, use it to send messages to this browser.
2. A mailbox to receive messages. The mailbox can be used in one of two ways, but not both.
  - `mailbox.receive()` will return a promise that will resolve on the next message received by the browser.
  - `mailbox.handle(callback)` will call the callback with the contents of a message each time one is received.
3. A function to send messages, that takes the target address and messages as arguments.
  The message must be serialisable to JSON.
4. Communal information from server, this can be anything including addresses for processes on the backend,
  such as the logger process in the examples above.

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
docker build -t gen-browser .
docker run -it -e SECRET=s3cr3t -p 8080:8080 gen-browser iex -S mix run examples/playground.exs
```

Or, if you have Elixir installed but not docker, mix can be used directly

```
SECRET=s3cr3t iex -S mix run examples/playground.exs
```

Open `examples/pinger.html` and `examples/ponger.html` in your browser.

## Server API

Addresses can just as easily be used from the backend.

### Embed in a Phoenix (or Plug) application

`GenBrowser` can be easily added to a Phoenix or Plug application using the `GenBrowser.Plug`.

In Phoenix add the plug to your `endpoint.ex`.
**NOTE:** it must be added after the Parser Plugs.

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # other plugs ...

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(GenBrowser.Plug, communal: %{myProcess: GenBrowser.Address.new(MyProcess)})
  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # more plugs
end
```

Just make sure your client code is pointing to the correct host,
normally `localhost:4000` for new Phoenix projects.

### Send a message to a client

First fetch the address of a running ponger browser.

In the server console

```sh
iex> address = "g2gCZAAGZ2xvYmFsaAJkABlFbGl4aXIuR2VuQnJvd3Nlci5NYWlsYm94bQAAAAxWR0hFWFkwZWExUEg=--qp7BCZMlqtGpO7nUDwQmZC4CkA-tPZE56uVISq6xEcU="
iex> {:ok, ponger} = GenBrowser.decode_address(address)
# {:ok, {:global, {GenBrowser.Mailbox, "VGHEXY0ea1PH"}}}

iex> GenBrowser.send(ponger, %{"type" => "ping", "from" => GenBrowser.Address.new(self)})
# {:ok, :sent}
iex> flush
# %{
#   "from" => "g2gCZAAGZ2xvYmFsaAJkABlFbGl4aXIuR2VuQnJvd3Nlci5NYWlsYm94bQAAAAxWR0hFWFkwZWExUEg=--qp7BCZMlqtGpO7nUDwQmZC4CkA-tPZE56uVISq6xEcU=",
#   "type" => "pong"
# }
# :ok
```

Any server process can be added to the clients communal at startup.

See the [playground example](examples/playground.exs)

Or follow the docs on [hexdoc.pm](https://hexdocs.pm/gen_browser/readme.html)

## Notes

### So experimental right now

Best thing to do is play with examples.

Check the [Roadmap](#Roadmap) for what I'm working on next.

### Rational

Client/Server is just another type of distributed system.
What if the whole system can be treated as a group of processes that send messages to each other.

#### Goal 1

Make it just as easy to send messages client to server and even client to client.

#### Goal 2

Model all communication as message passing so the system can be verified using session types or similar

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

The client created from `GenBrowser.start` is deliberatly temporary, it is analogous to a process on the server side.
It is perhaps closer to the concept of a session.

If the user wants to access some persistent data they should send a message, probably with authentication.
This message should indicate the persistent data to access and the current session to forward it to.

### Messages that are not understood

Messages can always not be understood by the server.
When using `send` the response is 202 accepted, this just means the server in general was happy the target process might not know how to handle the message.

The target process might not even know who the message came from, and so be unable to return an error.
In this case the system has to rely on timeouts and crashlogging.

To tackle this problem a standard message container could be provided,
it might include a standard format for sender, and perhaps tracing.
Such a standard format could easily be built on top of this library.

### Client outbound queue

The client is able to handle network interuptions on the receive side.
However if sending during a network interuption then the send will fail.

Messages could be automatically retried in case of 5xx response (but not 4xx),
This would require knowledge about the idempotency of the message in question.
`dispatch(address, message, retry)` where retry is true/false or function taking error.

### Ordering between two clients

The order of messages in the server mailbox is kept when streaming these to the client.
This does not guarantee ordering of messages sent from a client to a server process.
There is no correlation between requests sent.

The client could queue messages and only process the next once it has received an ack that the first is in the mailbox.
This does not need to be inefficient as it could send a list of messages in the case that it has multiple messages in the queue.

Simply queuing before sending would not guarantee order, the HTTP handling process on the backend would be different for each process.

### Addresses are large

Address encoding just makes use of `:erlang.term_to_binary` + `Base.url_encode64`.
With the addition of signing this makes for very large address strings.

If the encode function knew about all possible things that could be encoded then encoding could be super effiecient.
Say a single byte for which module will following bytes just handled by that module.

This would need some top level information about what spec the address was created with,
once things are sent to the client they can survive redeploys.

Connection would need to communicate that spec version `/mailbox/?spec=v1.1`
The secret for signing could be the spec id, however that probably just increases the risk of leaking the secret.

### Every event involves a signature

As it stands every event involves calculating a digest.
It is probably safe to sign just the mailbox_id and append the count number to the signed mailbox_id.
Currently the count number is appended to the mailbox_id and that combined cursor signed

### GenCall

A call function could exist, both where the server can call the client and block on response and vica versa.

This would require the send function to have a reference to the mailbox.
It would also require a selective receive, other push messages from the server might have arrived.
A standard call format would go someway to providing a standard message container as discussed in messages not understood.

### Security

A client should only be able to send message to addresses it has been provided with.
i.e. it should not be possible to guess the address of processes.

This is the Object capability security model https://en.wikipedia.org/wiki/Object-capability_model

By signing the event-id this method can be used to secure an individual clients reconnections

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

### Is this crazy?

Maybe.

Let me know what you think.

## Roadmap

### Write talk about Actors for the browser

Investigate Scala/JS/Redux events.

Send message to email address demo.

### Setup Docker image that can be pulled

install node on Docker
have docker build the npm packages
server the bundle under `/_gb`
JavaScript get your own source

### Develop a general purpose address structure

My suggesion for this is probably `{:comms, module, term}`,
where the module implementes the `:comms_address` behaviour.
Whe the message is sent it should call `module.dispatch(term, message)`

This tuple could also wrap other kinds of address e.g. `{:comms, pid}` and `{:comms, {:via, module, term}}`.
The value of this structure is that When mapping through data to send this can be matched on an securely serialized.

By this point we are very close to having `{mod, func, args}` as the structure of an address.
I guess the above alows a behaviour to have more than one function that can be used in different cases.

General purpose address structure will need information on starting processes.

Need to blog about how create new process is not a thing.

Actor model only needs two rules.
Analogy is employers are hired, send message to the recruitment deparatment, not spawned.

Address is abstract key for linearizability.
Create a `Comms.HTTP` for sending messages to an endpoint, or even a session?
Create a `Comm.CallReply` for replying to a call.

```elixir
def handle({:comms_call, from, :x}, state) do
  {[{from, :y}], state}
end
```

The other end will need to handle a Down/Timeout message, they should probably be the same form with different reason
```elixir
def handle({:comms_fail, reason, refence}, state) do
  {[{from, :y}], state}
end
```

In most cases send to a destination.
e.g.
```
send(email_address, message)
# better than
send(mailer, message+address)
```
The fact it goes through a mailer process is just an implementation detail.

linearizability should be enforcable by making a call, MyModule.dispatch could return conflict.

### Better encoding decoding

- Is it possible to encode and sign with a secret.
  The encode protocol would need to be able to pass custom options.
- What is the best way to iterate through an object before it gets jsoned

If not then `GenBrowser.Address` does not need to exist as a struct, because the protocol for json encoding will not be used.

Move the iterate through JSON function to web.

### Work out how to provide a validation layer for messages as they are received by server

Addresses should not need to know how to decode messages, there might be more than one transport format for messages.
However it is possible that addresses could also opt in to a second behaviour such as `GenBrowser.JSONTransport`
Should return error argument error.
I'm not sure it even makes sense to have addresses have a binary format, given general choice they would not choose to be url safe

`send` already returns a promise, awaiting on this could at least validate message was legit.

Do an example with Ecto as the form validation.

### Clear the server mailbox

Client should be able to send the ability to ack messages and clear up the contents of the server mailbox.

The server mailbox process should also have a timeout after which a reconnection is not possible.

Can the id of a reconnect be taken as an ack, or should that be sent separatly.

There should also be a timeout after which the mailbox process dies.
Finally we need to signal to the client in cases when a reconnect to a dead mailbox is attempted.

`Clients will reconnect if the connection is closed; a client can be told to stop reconnecting using the HTTP 204 No Content response code.`
This might not trigger an onerror, it might be best to on error on the client so sending a 4xx could be better

### Redux middleware

This is the comms goal, i.e. don't call send, just return a list of addresses and messages thus making the whole thing pure.

### Demonstrate with Redux

This could just be the redux swarm below.
There are ways to start new browser windows, this might be fun

### Support a multi-node backend

To support a multi node backend it is required to guarantee that only on server mailbox can exist for each client(mailbox_id)
`:global` can suffer split brain and so might not be an adequate solution.
However because we know when to create a new mailbox, and they are always started with a random id, it might be the case that a split brain is not a problem.
The effect of a split brain would be sometimes thinking a server mailbox had died when it was infact in the other partition.
This would require setting up a new mailbox, but this eventuallity already has to be accounted for.

### Composition of Effectful code

https://elixirforum.com/t/functionaly-pure-message-passing/11173

 Finally once the above is proved extract addresses and make a Comms.Monad and a general Comms.Worker.
 This work should be done after discovering if a general equivalent to `:gen.call` and `Process.monitor` are needed.

 Pure messages with comms means no untestable side effects EVER.
 How things are modelled through session types. By this point we might need Rust for affine types.

```elixir
Comms.for(message, state) do
  :ok <- send(a, :b)
  :ok <- send(foo, :bar)
after
  state
end
```

*Macro can rewrite address, to proxy affine types. However it's always possible to just assign variable earlier*
`{:ok, a} <- send(a, :b)`

Q? - how to expose error case if allowing error cases?

A good proof of concept of this should be in `Raxx.SimpleServer`

Needs a process that never needs starting. Is just transparently started,
Try Comms.Worker started locally, generated with id in place.
Uses global and relies on generated id really being random.
Can run the risk of having a hot node.

### Typing message sending

Ping pong typed example using dialyzer.

Look at existing work in comms/pachyderm.

To share this will be a recipe for working with dialyzer because lack of generics prevent solution being exported from a library.

### Session type interactions

This probably requires pure interactions.
Autowriting is a pretend for affine types.
Need multiparty to handle timout.

This is the point I am likely to seriously revist Rust

### Typed transport

Limited state types.

This builds on the fact that all the even numbers can be represented by droping the last bit,
and ensuring your type knows that they are even numbers.

If the language primative is binaries or maybe integers, both of those must exist in a range.
so instead of JSON where you can have any integer you have a spec which always includes an upper limit on the integer

Works for all countable sets (not transdentals) but I thnk this is a limit using computers has.

This is useful for sending things over the wire.
Opening a protocol probably has a hash of the protocol spec.

Also type operations can always be shown to go to a decreasing number of outcomes, and therefore total.

Once comms monad exists having totallity in a language is desirable.

The only language I know with this trait is idris.

### Work out if client can generate own address

Then no need to await at startup
