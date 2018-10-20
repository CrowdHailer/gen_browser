// TODO explain example for npm modules on eventsourcemock lib
const EventSource = require('eventsourcemock').default;
const sources = require('eventsourcemock').sources;

Object.defineProperty(window, 'EventSource', {
  value: EventSource,
});

const { start } = require('../dist/comms.js')

test('sending messages to the client', async () => {
  startPromise = start('http://comms.dev/1')
  const source = sources['http://comms.dev/1/mailbox']

  var data = '{"address":"myAddress","config":{"a":1,"b":2}}'
  var event = new MessageEvent('__comms__/init', {data: data})
  source.emitMessage(event)

  const {address, mailbox, send, config} = await startPromise
  expect(address).toBe("myAddress")
  expect(config).toEqual({a: 1, b: 2})

  var event = new MessageEvent('message', {data: '{"pong":true}'})
  source.emitMessage(event)

  var message = await mailbox.receive()
  expect(message).toEqual({pong: true})
})
