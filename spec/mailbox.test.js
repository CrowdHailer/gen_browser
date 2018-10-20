const { Mailbox } = require('../dist/comms.js')

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
