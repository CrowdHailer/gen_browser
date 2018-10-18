// import from backend config function
export function start (backend, options = {}) {
  // Can use on open to check if the connection is made in time
  // NOTE need to shutdown properly onerror
  // TODO expose error case, reject promise in case of await, error handler in callback version
  const mailbox = new Mailbox()

  return new Promise(function(resolve, reject) {
    const eventSource = new EventSource(mailboxURL(backend))

    eventSource.onmessage = function (event) {
      if (event.type != '__comms__/init') { raise 'Incorrect first event' }

      const {address, config} = JSON.parse(event.data)

      eventSource.onmessage = function (event) {
        // Use event type message becuase it's the default so one less field to send.
        if (event.type != 'message') { raise 'Unexpected event' }
        mailbox.deliver(event.data)
      }
      resolve({
        address: address
        mailbox: mailbox,
        send: function (address, message) { return send(backend, address, message) },
        config: config
      })
    }
  });
}

// Mailbox can have a deposit function, can use a facade to make it unavailable
// Call it deliver instead

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
