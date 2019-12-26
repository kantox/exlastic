defmodule Exlastic do
  @moduledoc """
  `Exlastic` is a opinionated [logger backend](https://hexdocs.pm/logger/Logger.html#module-backends)
  helper library to log events with [`telemetry`](https://hexdocs.pm/telemetry) attached.

  It is to be configured in `config.exs` in the following way:

  ```elixir
  config :exlastic,
    uri: "http://127.0.0.1:9200",
    events: [:app, :lib],
    handler: :elastic

  config :logger,
    backends: [Exlastic.Logger.Backend],
    level: :debug
  ```

  and might be used normally as a usual logger backend

  ```elixir
  Logger.info "users", %{name: "John", reference: "U-123456789"}
  ```

  Also it supports benchmarking with `#{__MODULE__}.bench/4`. The latter will
  execute the block passed to the function, surrounded with two calls to
  `#{__MODULE__}.log/4` to collect some additional info about this particular
  block execution.

  By default all the logger methods would attach `process_info` to the events
  sent to _Elastic_ to alter / discard this pass `process_info: SOMETHING` to
  the call to all the exported functions’ payload. Unless `SOMETHING` is `true`,
  this value will be used instead of real process info.
  """

  require Logger

  @typedoc false
  @type entity :: binary() | atom()

  @doc """
  Logs the payload with the telemetry attached to the configured _ElasticSearch_
  instance. The telemetry includes some process information by default, besides
  monotonic time and some additional parameters.

  The process info data might be altered or switched off by passing `:process_info`
  keyword parameter in call to `#{__MODULE__}.log/4`. `true` value (default) would
  collect and store the current process info; any other value would be passed through
  as is.

  * `level` parameter is one of `:debug | :info | :warn | :error`
  * `tag` is mapped to ElasticSearch index when passed; possible values must be configured in `config.exs` file in the list of telemetry events
  * `entity` parameter is the additional tagging that goes into payload, e. g. `"orders"`
  * `payload` is anything encodeable into `json`
  """
  defmacro log(level, tag \\ nil, entity, payload) do
    %{module: module, function: fun, file: file, line: line, context: context} = __CALLER__

    quote do
      event =
        if is_nil(unquote(tag)),
          do: [:exlastic, unquote(level)],
          else: [:exlastic, unquote(tag), unquote(level)]

      now = System.monotonic_time(:microsecond)
      {benchmark, payload} = Keyword.pop(unquote(payload), :benchmark, "N/A")
      {process_info, payload} = Keyword.pop(unquote(payload), :process_info, true)

      # [
      #   current_function: {Process, :info, 1},
      #   initial_call: {:proc_lib, :init_p, 5},
      #   status: :running,
      #   message_queue_len: 0,
      #   links: [],
      #   dictionary: [
      #     iex_evaluator: :ack,
      #     iex_history: %IEx.History{
      #       queue: {[
      #         {1,
      #           [:iex_evaluator, :iex_history, :iex_server, :"$initial_call",
      #           :"$ancestors"]}
      #       ], []},
      #       size: 1,
      #       start: 1
      #     },
      #     iex_server: #PID<0.82.0>,
      #     "$initial_call": {IEx.Evaluator, :init, 4},
      #     "$ancestors": [#PID<0.82.0>]
      #   ],
      #   trap_exit: false,
      #   error_handler: :error_handler,
      #   priority: :normal,
      #   group_leader: #PID<0.65.0>,
      #   total_heap_size: 9358,
      #   heap_size: 2586,
      #   stack_size: 45,
      #   reductions: 23791,
      #   garbage_collection: [
      #     max_heap_size: %{error_logger: true, kill: true, size: 0},
      #     min_bin_vheap_size: 46422,
      #     min_heap_size: 233,
      #     fullsweep_after: 65535,
      #     minor_gcs: 9
      #   ],
      #   suspending: []
      # ]
      process_info =
        if process_info == true do
          self()
          |> Process.info()
          |> Map.new()
          |> Map.take([
            :status,
            :message_queue_len,
            :priority,
            :total_heap_size,
            :heap_size,
            :stack_size,
            :reductions,
            :garbage_collection
          ])
          |> Map.update!(:garbage_collection, &Map.new/1)
          |> Map.put(:schedulers, System.schedulers())
        else
          process_info
        end

      :ok =
        :telemetry.execute(
          event,
          %{
            benchmark: benchmark,
            now: now,
            entity: unquote(entity),
            process_info: process_info,
            metadata: %{
              context: unquote(context),
              module: unquote(module),
              function: unquote(fun),
              file: unquote(file),
              line: unquote(line)
            }
          },
          Map.new(payload)
        )

      {:ok, now}
    end
  end

  Enum.each([:error, :warn, :info, :debug], fn level ->
    @doc "Helper macro to produce a logger entry with level **`#{level}`**."
    defmacro unquote(level)(tag \\ nil, entity, payload),
      do: log(unquote(level), tag, entity, payload)
  end)

  @doc """
  Similar to `#{__MODULE__}.log/4` but also accepts a block.

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

      {:ok, now} = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      result = unquote(block)

      payload =
        payload
        |> Keyword.put(:__tag__, :out)
        |> Keyword.put(:benchmark, System.monotonic_time(:microsecond) - now)

      {:ok, _} = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      {:ok, result, payload}
    end
  end
end
