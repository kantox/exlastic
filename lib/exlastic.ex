defmodule Exlastic do
  @moduledoc """
  Documentation for Exlastic.
  """

  require Logger

  @type entity :: binary() | atom()

  @doc """
  Generic log function.
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
