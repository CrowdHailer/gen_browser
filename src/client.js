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
      resolve({
        address: address,
        mailbox: mailbox,
        send: function (address, message) { return send(backend, address, message) },
        config: config
      })
    }
    eventSource.onerror = function (error) {
      // only in the case of a 204 response will the readyState transition to '2'
      console.log("READYSTATE", eventSource.readyState)
      // Needs to call mailbox.close
      // Which should affect await and handle
      // console.warn(error)
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
  return fetch(sendURL(backend, address), {
    method: 'POST',
    body: JSON.stringify(data),
    // Not sure that is still necessary
    mode: 'no-cors'
  })
}
