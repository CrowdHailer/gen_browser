# GenBrowser

**Make a browser look like any other Elixir/erlang process**

Client server is just another distributed system,
lets have a process model that covers them all.

**So experimental right now**

This works by giving browser pages a web address that can be used on the elixir side, and by providing a way to serialize pids so they can be used by the client.

## What to do

- clone this repo
- pull dependencies `mix deps.get`
- start the project `iex -S mix`
- visit `localhost:8080`
- open the console

Addresses have to be provided by the server,
it would be insecure to allow clients to construct their own process references.
In the future these server generated references will be signed, in the same way as session cookies

This project has been set up to allow you to talk to browsers and processes as if they are the same thing.
Extracting it to a library is still todo, and something I would like help with. particularly around the JavaScript.

### Talk to your self

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

## GenBrowser client API?

```js
var client = new GenBrowser({
  init: function(state){
    console.log(state)
    return state
  },
  handle_info: function(message, state){
    console.log(message)
    if (message.your_pair) {
      console.log('paired with', message.your_pair)
      state.pair = message.your_pair
      your_pair.innerHTML = message.your_pair
    }
    if (message.text) {
      displayUpdate(message.text)
    }
    return state
  }
})
```

A GenBrowser client has to implement two callbacks.

- `init` called when first connected.
  The state given to this callback is from the server,
  Because the client can only communicate to process it knows about this is how we tell our example about the logger and pair_up process.
- `handle_info` called for every message sent to the browser.
