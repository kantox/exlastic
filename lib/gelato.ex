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

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Gelato
      require Logger
    end
  end

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

      tag = to_string(unquote(tag))

      payload =
        unquote(payload)
        |> Keyword.put(:__reference__, reference)
        |> Keyword.put(:__tag__, :in)
        |> Keyword.put(:entity, unquote(entity))

      :ok = Logger.log(unquote(level), tag, payload)

      now = System.monotonic_time(:microsecond)
      result = unquote(block)
      benchmark = System.monotonic_time(:microsecond) - now

      payload =
        payload
        |> Keyword.put(:__tag__, :out)
        |> Keyword.put(:benchmark, benchmark)

      :ok = Logger.log(unquote(level), tag, payload)

      {:ok, result, payload}
    end
  end

  @doc """
  Defines a function that delegates to another module and wraps the delegated call
  into `Gelato.bench/4`. Similar to `Kernel.defdelegate/2`.

  Functions defined with `defdelegatelog/2` are public and can be invoked from
  outside the module they’re defined in, as if they were defined using `def/2`.

  ## Options
    * `:to` — the module to dispatch to.
    * `:as` — the function to call on the target given in `:to`.
      This parameter is optional and defaults to the name being delegated (`fun`).
    * `:level` — the level to be used for wrapping logging, default `:info`
    * `:tag` — the tag to be used as an index in the target Elastic call.
      Default: `"default"`.
    * `:entity` — additional key to simplify search in Elastic logs. Usually
      it specifies a business entity, loke `:user`, or `:order`. Default: `nil`.

  ## Examples
      defmodule MyList do
        defdelegatelog reverse(list), to: Enum
      end
      MyList.reverse([1, 2, 3])
      #   Logger.log is called under the hood with telemetry metrics attached
      #=> [3, 2, 1]
      #   Logger.log is called under the hood with telemetry metrics attached
  """
  defmacro defdelegatelog(fun, opts) do
    fun = Macro.escape(fun, unquote: true)

    quote bind_quoted: [fun: fun, opts: opts] do
      target =
        Keyword.get(opts, :to) ||
          raise ArgumentError, "expected `to:` destination module to be given as argument"

      {name, args, as, as_args} = Kernel.Utils.defdelegate(fun, opts)
      level = Keyword.get(opts, :level, :info)
      tag = Keyword.get(opts, :tag, "default")
      entity = Keyword.get(opts, :entity)

      @doc delegate_to: {target, as, :erlang.length(as_args)}

      def unquote(name)(unquote_splicing(args)) do
        {:ok, result, _payload} =
          Gelato.bench unquote(level), unquote(tag), unquote(entity) do
            unquote(target).unquote(as)(unquote_splicing(as_args))
          end

        result
      end
    end
  end
end
