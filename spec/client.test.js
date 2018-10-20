// TODO explain example for npm modules on eventsourcemock lib
const EventSource = require('eventsourcemock').default;
const sources = require('eventsourcemock').sources;

Object.defineProperty(window, 'EventSource', {
  value: EventSource,
});

const { start } = require('../dist/gen-browser.js')

test('Sending messages to the client until connection closed', async () => {
  startPromise = start('http://gen-browser.dev/1')
  const source = sources['http://gen-browser.dev/1/mailbox']

  var data = '{"type":"__gen_browser__/init","address":"myAddress","config":{"a":1,"b":2}}'
  var event = new MessageEvent('message', {data: data})
  source.emitMessage(event)

  const {address, mailbox, send, config} = await startPromise
  expect(address).toBe("myAddress")
  expect(config).toEqual({a: 1, b: 2})

  var event = new MessageEvent('message', {data: '{"pong":true}'})
  source.emitMessage(event)

  var message = await mailbox.receive()
  expect(message).toEqual({pong: true})

  source.emitError()
  source.emitMessage(event)

  var message = await mailbox.receive()
  expect(message).toEqual({pong: true})

  source.close()
  source.emitError()

  return mailbox.receive().catch((error) => {
    expect(error).toBe('Mailbox has been closed')
  })
})

test('Starting a client will be rejected after timeout', async () => {
  return start('http://gen-browser.dev/2', {timeout: 100}).catch((error) => {
    expect(error).toBe('Timed out in 100ms.')
  })
})

test('Starting a client will be rejected if eventSource will no longer retry', async () => {
  const promise = start('http://gen-browser.dev/3')
  const source = sources['http://gen-browser.dev/3/mailbox']
  source.close()
  source.emitError()
  return promise.catch((error) => {
    expect(error).toBe('Failed to connect to \'http://gen-browser.dev/3/mailbox\'')
  })
})
