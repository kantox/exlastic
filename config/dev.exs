import Config

config :gelato,
  uri: "http://127.0.0.1:9200",
  events: [:app, :lib],
  handler: :elastic

config :logger,
  backends: [Gelato.Logger.Backend],
  level: :debug
