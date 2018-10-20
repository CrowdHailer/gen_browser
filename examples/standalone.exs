Ace.HTTP.Service.start_link({GenBrowser.Raxx, %{secrets: ["not_secret_at_all"]}},
  port: 8080,
  cleartext: true
)
