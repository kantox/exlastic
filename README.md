# ![Gelato](/stuff/logo-48x48.png?raw=true) Gelato

An opinionated [logger backend](https://hexdocs.pm/logger/Logger.html#module-backends) helper library to log events with [`telemetry`](https://hexdocs.pm/telemetry) attached.

## Installation

```elixir
def deps do
  [
    {:gelato, "~> 0.2"}
  ]
end
```

## Usage

```elixir
# sends the single event with attached process info to Elastic server
Logger.info "users", name: "John", reference: "U-123456789"

# sends the “in” and “out” events to Elastic server, with some collected
#   stats in “out” events; discards process info
Gelato.bench :info, "users", name: "John", reference: "U-123456789", process_info: "N/A"
```

Besides `Gelato.bench/4`, this library provides `Gelato.defdelegatelog/2` macro
that might be used for mastering interfaces to internal codepieces _featured by telemetry log_.

Once delegated, the function is being wrapped into `Gelato.bench/4` call.
The following example is taken from tests.

```elixir
defmodule Gelato.Test.DDL.Helper do
  @moduledoc false
  def yo(arg), do: {:ok, arg}
end

defmodule Gelato.Test.DDL.Test do
  @moduledoc false
  use Gelato

  defdelegatelog yo_test(arg),
                 to: Gelato.Test.DDL.Helper,
                 as: :yo,
                 level: :warn,
                 tag: "app",
                 entity: :ddl
end
```

## [Documentation](https://hexdocs.pm/gelato).

