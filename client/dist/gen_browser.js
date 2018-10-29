(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
  typeof define === 'function' && define.amd ? define(['exports'], factory) :
  (factory((global.GenBrowser = {})));
}(this, (function (exports) { 'use strict';

  function promiseTimeout(promise, milliseconds){

    // Create a promise that rejects in <ms> milliseconds
    let timeout = new Promise((resolve, reject) => {
      let id = setTimeout(() => {
        clearTimeout(id);
        reject('Timed out in '+ milliseconds + 'ms.');
      }, milliseconds);
    });

    // Returns a race between our timeout and the passed in promise
    return Promise.race([
      promise,
      timeout
    ])
  }

  function Mailbox () {
    // NOTE there should be a maximum mailbox size, slop and reconnect possible?
    // NOTE there might need to be a function to expose if mailbox closed, only true if closed and empty.
    // Can use receive with zero timeout?
    // NOTE expose a function to see the number of message in mailbox, probably just called size
    const messages = [];
    var awaiting;
    var customMessageHandler;
    var customCloseHandler;
    var closed = false;

    // Pass resolve as a second argument here and the function doesn't need to get defined for each mailbox
    function standardMessageHandler(message) {
      messages.push(message);
      if (awaiting) {
        const {resolve: resolve, reject: reject} = awaiting;
        const next = messages.shift();
        awaiting = undefined;
        resolve(next);
      }
    }

    function standardCloseHandler () {
      if (awaiting) {
        const {resolve: resolve, reject: reject} = awaiting;
        awaiting = undefined;
        reject('Mailbox has been closed');
      } else {
        console.log('Mailbox has been closed');
      }
    }

    // maybe deposit
    this.deliver = function (message) {
      (customMessageHandler || standardMessageHandler)(message);
    };

    this.close = function () {
      if (closed) {
        throw('Mailbox is already closed')
      }
      closed = true;
      (customCloseHandler || standardCloseHandler)();
    };

    this.receive = function (options = {}) {
      const milliseconds = options.timeout || 5000;
      if (customMessageHandler) {
        throw 'Cannot receive because a custom handler has been set on this mailbox'
      }
      if (awaiting) {
        throw 'Receiver is already awaiting message'
      }
      const next = messages.shift();
      // What is the message is undefined, need to handle such a case
      // Just don't allow deliver to accept undefined
      var receivePromise = new Promise(function(resolve, reject) {
        if (next == undefined) {
          if (closed) {
            reject('Mailbox has been closed');
          } else {
            awaiting = {resolve: resolve, reject: reject};
          }
        } else {
          resolve(next);
        }
      });
      return promiseTimeout(receivePromise, milliseconds).catch((error) => {
        // In case of timeout awaiting will promise gets rejected.
        awaiting = undefined;
        throw(error)
      })
    };
    this.setHandler = function (messageHandler, closeHandler) {
      if (customMessageHandler == undefined) {
        customMessageHandler = messageHandler;
        customCloseHandler = closeHandler;
        var next;
        while (next = messages.shift()) {
          customMessageHandler(next);
        }
        if (closed && customCloseHandler) {
          customCloseHandler();
        }
      } else {
        throw 'Custom handler has already been set on this mailbox'
      }
    };
  }

  function start (backend = '', options = {}) {
    // Can use on open to check if the connection is made in time
    // NOTE need to shutdown properly onerror
    const milliseconds = options.timeout || 5000;
    const mailbox = new Mailbox();
    backend = backend + "/_gb";
    const mbURL = mailboxURL(backend);

    const eventSource = new EventSource(mbURL);
    const startPromise = new Promise(function(resolve, reject) {

      // onmessage is only called if the type is "message"
      // https://stackoverflow.com/questions/9933619/html5-eventsource-listener-for-all-events
      eventSource.onmessage = function (event) {
        const {type, address, communal} = JSON.parse(event.data);
        if (type != '__gen_browser__/init') { reject('Server emitted incorrect first event'); }

        eventSource.onmessage = function (event) {
          // Use event type message becuase it's the default so one less field to send.
          // I think just throwing wont remove the handler
          if (event.type != 'message') { throw 'Unexpected event' }
          mailbox.deliver(JSON.parse(event.data));
        };
        eventSource.onerror = function (error) {
          if (eventSource.readyState == 2) {
            mailbox.close();
          }
        };
        resolve({
          address: address,
          mailbox: mailbox,
          send: function (address, message) { return send(backend, address, message) },
          communal: communal
        });
      };
      eventSource.onerror = function (error) {
        if (eventSource.readyState == 2) {
          reject('Failed to connect to \'' + mbURL + '\'');
        }
      };
    });
    return promiseTimeout(startPromise, milliseconds).catch((error) => {
      // In case of timeout close the event source, in other cases calling close is idempotent.
      eventSource.close();
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

  exports.Mailbox = Mailbox;
  exports.start = start;

  Object.defineProperty(exports, '__esModule', { value: true });

})));
