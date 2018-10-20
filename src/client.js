import Mailbox from './mailbox.js'
export { Mailbox }
// import from backend config function
export function start (backend, options = {}) {
  // Can use on open to check if the connection is made in time
  // NOTE need to shutdown properly onerror
  // TODO expose error case, reject promise in case of timeout, error handler in callvac
  const mailbox = new Mailbox()

  return new Promise(function(resolve, reject) {
    const eventSource = new EventSource(mailboxURL(backend))

    eventSource.onmessage = function (event) {
      if (event.type != '__comms__/init') { reject('Server emitted incorrect first event') }

      const {address, config} = JSON.parse(event.data)

      eventSource.onmessage = function (event) {
        // Use event type message becuase it's the default so one less field to send.
        // I think just throwing wont remove the handler
        if (event.type != 'message') { throw 'Unexpected event' }
        mailbox.deliver(JSON.parse(event.data))
      }
      resolve({
        address: address,
        mailbox: mailbox,
        send: function (address, message) { return send(backend, address, message) },
        config: config
      })
    }
  });
}

function mailboxURL(backend) {
  return backend + '/mailbox'
}

function sendURL(backend, address) {
  return backend + '/send/' + address
}

function send(backend, address, data) {
  return fetch(send_url(backend, address), {
    method: 'POST',
    body: JSON.stringify(data),
    // Not sure that is still necessary
    mode: 'no-cors'
  })
}
