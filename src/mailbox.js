import promiseTimeout from './promiseTimeout.js'

export default function Mailbox () {
  // NOTE there should be a maximum mailbox size, slop and reconnect possible?
  // NOTE there might need to be a function to expose if mailbox closed, only true if closed and empty.
  // Can use receive with zero timeout?
  // NOTE expose a function to see the number of message in mailbox, probably just called size
  const messages = []
  var awaiting
  var customMessageHandler
  var customCloseHandler
  var closed = false

  // Pass resolve as a second argument here and the function doesn't need to get defined for each mailbox
  function standardMessageHandler(message) {
    messages.push(message)
    if (awaiting) {
      const {resolve: resolve, reject: reject} = awaiting
      const next = messages.shift()
      awaiting = undefined
      resolve(next)
    }
  }

  function standardCloseHandler () {
    if (awaiting) {
      const {resolve: resolve, reject: reject} = awaiting
      awaiting = undefined
      reject('Mailbox has been closed')
    }
  }

  // maybe deposit
  this.deliver = function (message) {
    (customMessageHandler || standardMessageHandler)(message)
  }

  this.close = function () {
    // NOTE should an error be raised if closing twice, or should it be idempotent and call nothing.
    closed = true;
    (customCloseHandler || standardCloseHandler)()
  }

  this.receive = function (options = {}) {
    const milliseconds = options.timeout || 5000
    if (customMessageHandler) {
      throw 'Cannot receive because a custom handler has been set on this mailbox'
    }
    if (awaiting) {
      throw 'Receiver is already awaiting message'
    }
    const next = messages.shift()
    // What is the message is undefined, need to handle such a case
    // Just don't allow deliver to accept undefined
    var receivePromise = new Promise(function(resolve, reject) {
      if (next == undefined) {
        if (closed) {
          reject('Mailbox has been closed')
        } else {
          awaiting = {resolve: resolve, reject: reject}
        }
      } else {
        resolve(next)
      }
    });
    return promiseTimeout(receivePromise, milliseconds)
  }
  this.setHandler = function (messageHandler, closeHandler) {
    if (customMessageHandler == undefined) {
      customMessageHandler = messageHandler
      customCloseHandler = closeHandler
      var next
      while (next = messages.shift()) {
        customMessageHandler(next)
      }
      if (closed && customCloseHandler) {
        customCloseHandler()
      }
    } else {
      throw 'Custom handler has already been set on this mailbox'
    }
  }
}
