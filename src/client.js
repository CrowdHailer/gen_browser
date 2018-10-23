import Mailbox from './mailbox.js'
import promiseTimeout from './promiseTimeout.js'
export { Mailbox }
// import from backend config function
export function start (backend, options = {}) {
  // Can use on open to check if the connection is made in time
  // NOTE need to shutdown properly onerror
  const milliseconds = options.timeout || 5000
  const mailbox = new Mailbox()
  backend = backend + "/_gb"
  const mbURL = mailboxURL(backend)

  const eventSource = new EventSource(mbURL)
  const startPromise = new Promise(function(resolve, reject) {

    // onmessage is only called if the type is "message"
    // https://stackoverflow.com/questions/9933619/html5-eventsource-listener-for-all-events
    eventSource.onmessage = function (event) {
      const {type, address, config} = JSON.parse(event.data)
      if (type != '__gen_browser__/init') { reject('Server emitted incorrect first event') }

      eventSource.onmessage = function (event) {
        // Use event type message becuase it's the default so one less field to send.
        // I think just throwing wont remove the handler
        if (event.type != 'message') { throw 'Unexpected event' }
        mailbox.deliver(JSON.parse(event.data))
      }
      eventSource.onerror = function (error) {
        if (eventSource.readyState == 2) {
          mailbox.close()
        }
      }
      resolve({
        address: address,
        mailbox: mailbox,
        send: function (address, message) { return send(backend, address, message) },
        config: config
      })
    }
    eventSource.onerror = function (error) {
      if (eventSource.readyState == 2) {
        reject('Failed to connect to \'' + mbURL + '\'')
      }
    }
  });
  return promiseTimeout(startPromise, milliseconds).catch((error) => {
    // In case of timeout close the event source, in other cases calling close is idempotent.
    eventSource.close()
    throw(error)
  })
}

function mailboxURL(backend) {
  return backend + '/mailbox'
}

function sendURL(backend, address) {
  return backend + '/send/' + address
}

function send(backend, address, data) {
  return fetch(sendURL(backend, address), {
    method: 'POST',
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      // "Content-Type": "application/x-www-form-urlencoded",
    },
    body: JSON.stringify(data),
    // mode: 'no-cors'
  })
}
