defmodule Gelato do
  @moduledoc """
  `Gelato` is a opinionated [logger backend](https://hexdocs.pm/logger/Logger.html#module-backends)
  helper library to log events with [`telemetry`](https://hexdocs.pm/telemetry) attached.

  It is to be configured in `config.exs` in the following way:

  ```elixir
  config :gelato,
    uri: "http://127.0.0.1:9200",
    events: [:app, :lib],
    handler: :elastic

  config :logger,
    backends: [Gelato.Logger.Backend],
    level: :debug
  ```

  and might be used normally as a usual logger backend

  ```elixir
  Logger.info "users", name: "John", reference: "U-123456789"
  ```

  Basically, it logs the payload with the telemetry attached to the configured
  _ElasticSearch_ instance. The telemetry includes some process information
  by default, besides monotonic time and some additional parameters.

  The process info data might be altered or switched off by passing `:process_info`
  keyword parameter in call to `Logger.log/3`. `true` value (default) would
  collect and store the current process info; any other value would be passed through
  as is.

  * `level` parameter is one of `:debug | :info | :warn | :error`
  * `message` is mapped to ElasticSearch index when passed; possible values must be configured in `config.exs` file in the list of telemetry events
  * `payload` is a keyword list to be passed to _Elastic_

  Also it supports benchmarking with `#{__MODULE__}.bench/4`. The latter will
  execute the block passed to the function, surrounded with two calls to
  `Logger.log/3` to collect some additional info about this particular
  block execution.

  By default all the logger methods would attach `process_info` to the events
  sent to _Elastic_ to alter / discard this pass `process_info: SOMETHING` to
  the call to all the exported functions’ payload. Unless `SOMETHING` is `true`,
  this value will be used instead of real process info.
  """

  @typedoc false
  @type entity :: binary() | atom()

  @doc """
  Similar to `Logger.log/3` but accepts a block.

  The block will be executed, surrounded by calls to `log` and the
  telemetry data will be accumulated in the latter call.
  """
  @spec bench(
          level :: Logger.level(),
          tag :: atom(),
          entity :: entity(),
          payload_and_do_block :: keyword()
        ) :: any()
  defmacro bench(level, tag \\ nil, entity, payload_and_do_block) do
    {block, payload} = Keyword.pop(payload_and_do_block, :do, :ok)

    quote do
      reference = inspect(make_ref())

      payload =
        unquote(payload)
        |> Keyword.put(:__reference__, reference)
        |> Keyword.put(:__tag__, :in)
        |> Keyword.put(:entity, unquote(entity))

      :ok = Logger.log(unquote(level), unquote(tag), payload)

      now = System.monotonic_time(:microsecond)
      result = unquote(block)
      benchmark = System.monotonic_time(:microsecond) - now

      payload =
        payload
        |> Keyword.put(:__tag__, :out)
        |> Keyword.put(:benchmark, benchmark)

      :ok = Logger.log(unquote(level), unquote(tag), payload)

      {:ok, result, payload}
    end
  end
end
