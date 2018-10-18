function Mailbox () {
  // NOTE there should be a maximum mailbox size
  // NOTE expose a function to see the number of message in mailbox, probably just called size
  const messages = []
  var awaiting
  var customHandler

  // Pass resolve as a second argument here and the function doesn't need to get defined for each mailbox
  function standardHandler(message) {
    messages.push(message)
    if (awaiting) {
      const {resolve: resolve, reject: reject} = awaiting
      const next = messages.shift()
      awaiting = undefined
      resolve(next)
    }
  }
  // maybe deposit
  this.deliver = function (message) {
    (customHandler || standardHandler)(message)
  }

  this.receive = function () {
    if (customHandler) {
      throw 'Cannot receive because a custom handler has been set on this mailbox'
    }
    if (awaiting) {
      throw 'Receiver is already awaiting message'
    }
    const next = messages.shift()
    // What is the message is undefined, need to handle such a case
    // Just don't allow deliver to accept undefined
    return new Promise(function(resolve, reject) {
      if (next == undefined) {
        awaiting = {resolve: resolve, reject: reject}
      } else {
        resolve(next)
      }
    });
  }
  this.setHandler = function (handler) {
    if (customHandler == undefined) {
      customHandler = handler
      var next
      while (next = messages.shift()) {
        customHandler(next)
      }
    } else {
      throw 'Custom handler has already been set on this mailbox'
    }
  }
}

test('message can be delivered before caller receives it', async () => {
  const mailbox = new Mailbox()
  const firstMessage = {text: 'first message'}
  mailbox.deliver(firstMessage)
  const secondMessage = {text: 'second message'}
  mailbox.deliver(secondMessage)

  expect(await mailbox.receive()).toBe(firstMessage)
  expect(await mailbox.receive()).toBe(secondMessage)
});

test('receiving a message will resolve when next message is available', async () => {
  const mailbox = new Mailbox()
  const promise = mailbox.receive()

  const firstMessage = {text: 'first message'}
  mailbox.deliver(firstMessage)

  expect(await promise).toBe(firstMessage)

  const secondMessage = {text: 'second message'}
  mailbox.deliver(secondMessage)

  expect(await mailbox.receive()).toBe(secondMessage)
})

test('Only one receive call can be pending at a time', async () => {
  const mailbox = new Mailbox()
  const promise = mailbox.receive()
  expect(mailbox.receive).toThrow('Receiver is already awaiting message')
})

test('Custom handler can be set on a mailbox', async () => {
  const mailbox = new Mailbox()
  var message

  const firstMessage = {text: 'first message'}
  mailbox.deliver(firstMessage)
  mailbox.setHandler((m) => {message = m})

  expect(message).toBe(firstMessage)

  const secondMessage = {text: 'second message'}
  mailbox.deliver(secondMessage)
  expect(message).toBe(secondMessage)
})

test('Can not receive messages on mailbox with a custom handler', async () => {
  const mailbox = new Mailbox()
  mailbox.setHandler((m) => { /* DO NOTHING */})
  expect(mailbox.receive).toThrow('Cannot receive because a custom handler has been set on this mailbox')
})

test('Can only set a custom handler once', async () => {
  const mailbox = new Mailbox()
  mailbox.setHandler((m) => { /* DO NOTHING */})
  expect(() => {mailbox.setHandler((m) => { /* DO NOTHING */})}).toThrow('Custom handler has already been set on this mailbox')
})
