const { Mailbox } = require('../dist/gen-browser.js')

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

test('Receive will be rejected after timeout', async () => {
  const mailbox = new Mailbox()
  return mailbox.receive({timeout: 100}).catch((error) => {
    expect(error).toBe('Timed out in 100ms.')
  })
})

test('Only one receive call can be pending at a time', async () => {
  const mailbox = new Mailbox()
  const promise = mailbox.receive()
  expect(() => {
    mailbox.receive()
  }).toThrow('Receiver is already awaiting message')
})

test('Receiving on a closed mailbox will be rejected', async () => {
  const mailbox = new Mailbox()
  mailbox.close()
  return mailbox.receive().catch((error) => {
    expect(error).toBe('Mailbox has been closed')
  })
})

test('Closing a mailbox will reject any pending receive', async () => {
  const mailbox = new Mailbox()
  const promise = mailbox.receive()
  mailbox.close()
  return promise.catch((error) => {
    expect(error).toBe('Mailbox has been closed')
  })
})

test('Messages on a closed mailbox can still be received', async () => {
  const mailbox = new Mailbox()
  const firstMessage = {text: 'first message'}
  mailbox.deliver(firstMessage)
  mailbox.close()

  expect(await mailbox.receive()).toBe(firstMessage)
  return mailbox.receive().catch((error) => {
    expect(error).toBe('Mailbox has been closed')
  })
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

test('Custom handler is called when the mailbox is closed', async () => {
  const mailbox = new Mailbox()
  var closed = false

  mailbox.setHandler((m) => { /* DO NOTHING */}, () => {closed = true})
  mailbox.close()
  expect(closed).toBe(true)
})

test('Adding a custom handler is automatically called if the mailbox has closed', async () => {
  const mailbox = new Mailbox()
  const firstMessage = {text: 'first message'}
  mailbox.deliver(firstMessage)
  mailbox.close()

  var message
  var closed = false
  mailbox.setHandler((m) => {message = m}, () => {closed = true})
  expect(message).toBe(firstMessage)
  expect(closed).toBe(true)
})
