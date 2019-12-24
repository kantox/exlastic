import Config

config :tirexs, :uri, "http://127.0.0.1:9200"

config :exlastic,
  uri: "http://127.0.0.1:9200",
  events: [:foo]

config :logger,
  backends: [Exlastic.Logger.Backend],
  level: :debug
