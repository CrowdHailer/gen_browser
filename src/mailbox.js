import promiseTimeout from './promiseTimeout.js'

export default function Mailbox () {
  // NOTE there should be a maximum mailbox size
  // NOTE expose a function to see the number of message in mailbox, probably just called size
  const messages = []
  var awaiting
  var customHandler

  // Pass resolve as a second argument here and the function doesn't need to get defined for each mailbox
  function standardHandler(message) {
    messages.push(message)
    if (awaiting) {
      const {resolve: resolve, reject: reject} = awaiting
      const next = messages.shift()
      awaiting = undefined
      resolve(next)
    }
  }
  // maybe deposit
  this.deliver = function (message) {
    (customHandler || standardHandler)(message)
  }

  this.receive = function (options = {}) {
    const milliseconds = options.timeout || 5000
    if (customHandler) {
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
        awaiting = {resolve: resolve, reject: reject}
      } else {
        resolve(next)
      }
    });
    return promiseTimeout(receivePromise, milliseconds)
  }
  this.setHandler = function (handler) {
    if (customHandler == undefined) {
      customHandler = handler
      var next
      while (next = messages.shift()) {
        customHandler(next)
      }
    } else {
      throw 'Custom handler has already been set on this mailbox'
    }
  }
}
