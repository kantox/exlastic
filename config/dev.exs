import Config

config :exlastic,
  uri: "http://127.0.0.1:9200",
  events: [:app, :lib],
  handler: :elastic

config :logger,
  backends: [Exlastic.Logger.Backend],
  level: :debug
