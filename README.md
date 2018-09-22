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

A bunch of random addresses have been written to the browser window object.

### Talk to a back end process.

```js
sendMessage(window.logger, {hello: 'world'})
```

in the iex shell you should see
```
"I got this message, %{\"hello\" => \"world\"}"
```

### Talk to your self

```js
sendMessage(window.self, {message: 'bounce'})
```

You should see the message written into the browser console

### Talk to another browser

There is a named process on the server that will pair up processes that talk to it.
this will require two browser consoles.

```js
// console 1
sendMessage(window.pair_up, {pair_me: window.self})
```
```js
// console 2
sendMessage(window.pair_up, {pair_me: window.self})
```

After both have sent a pair_up message you should see the following logged
```
paired with g2gCZAAGZ2xvYmFsaAJkABZFbGl4aXIuR2VuQnJvd3Nlci5QYWdlbQAAAAYwNTUwNjU=
```

And the pair will be written to the window object

```js
// console 1
sendMessage(window.pair, {message: 'hello friend'})
```

This message will have been delivered to browser 2
```js
// console 2
//{message: "hello friend"}
```

## A better API?
```js
var client = new GenBrowser({
  init: function(state){
    GenBrowser.send(this.address(), {message: 'bounce'})
    state
  },
  handle: function(message, state){
    GenBrowser.reply(message.from, "my reply")
    state
  }
})
client.start('/events')
client.start('/_genBrowser')
// Can easily send a call from server to client.
// would be best to only get reference to client once initialized
client.start('/_genBrowser', function (address) {
  window.address
  // of something in redux state.
})
```
