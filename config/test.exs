import Config

config :gelato,
  events: [:app, :lib],
  handler: :stdout

config :logger,
  backends: [Gelato.Logger.Backend],
  level: :debug
