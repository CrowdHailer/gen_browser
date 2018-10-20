// TODO explain example for npm modules on eventsourcemock lib
const EventSource = require('eventsourcemock').default;
const sources = require('eventsourcemock').sources;

Object.defineProperty(window, 'EventSource', {
  value: EventSource,
});

const { start } = require('../dist/gen-browser.js')

test('sending messages to the client', async () => {
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
})
