# ![Gelato](/stuff/logo-48x48.png?raw=true) Gelato

An opinionated [logger backend](https://hexdocs.pm/logger/Logger.html#module-backends) helper library to log events with [`telemetry`](https://hexdocs.pm/telemetry) attached.

## Installation

```elixir
def deps do
  [
    {:gelato, "~> 0.1"}
  ]
end
```

## Usage

```elixir
# sends the single event with attached process info to Elastic server
Gelato.info "users", name: "John", reference: "U-123456789"

# sends the “in” and “out” events to Elastic server, with some collected
#   stats in “out” events; discards process info
Gelato.bench "users", name: "John", reference: "U-123456789", process_info: "N/A"
```

## [Documentation](https://hexdocs.pm/gelato).

