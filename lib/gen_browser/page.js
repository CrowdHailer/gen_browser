function GenBrowser({init, handle_info, namespace}){
  var eventSource
  var client = this

  init = init.bind(client)
  handle_info = handle_info.bind(client)
  namespace = namespace || '/_gen_browser'

  mailbox_url = namespace + '/mailbox'
  function send_url(address){
    return namespace + '/send/' + address
  }
  console.log(mailbox_url)

  client.send = function (address, data) {
    fetch(send_url(address), {
      method: 'POST',
      body: JSON.stringify(data),
      mode: 'no-cors'
    })
  }

  eventSource = new EventSource(mailbox_url)
  eventSource.addEventListener('gen_browser', function (event) {
    var {id, address, config} = JSON.parse(event.data)
    client.id = id
    client.address = address
    client.state = init(config)
  })
  eventSource.addEventListener('message', function (event) {
    var data = JSON.parse(event.data)
    client.state = handle_info(data, client.state)
  })
}
