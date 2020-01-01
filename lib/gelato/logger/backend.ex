defmodule Gelato.Logger.Backend do
  @moduledoc false

  @behaviour :gen_event

  @spec tm(level :: Logger.level(), pid :: pid(), binary(), keyword()) :: :ok
  defmacrop tm(level, pid, tag, payload) do
    quote location: :keep do
      event =
        if is_nil(unquote(tag)),
          do: [:gelato, unquote(level)],
          else: [:gelato, String.to_atom(unquote(tag)), unquote(level)]

      metadata =
        Logger.metadata()
        |> Keyword.update(:pid, inspect(unquote(pid)), &inspect/1)

      payload = unquote(payload)
      now = System.monotonic_time(:microsecond)

      {benchmark, payload} = Keyword.pop(payload, :benchmark, "N/A")
      {process_info, payload} = Keyword.pop(payload, :process_info, true)
      {entity, payload} = Keyword.pop(payload, :entity, metadata[:module])
      {handler, payload} = Keyword.pop(payload, :handler, :elastic)

      :ok =
        :telemetry.execute(
          event,
          %{
            benchmark: benchmark,
            handler: handler,
            now: now,
            entity: entity,
            process_info: process_info(unquote(pid), process_info),
            metadata: Map.new(metadata)
          },
          Map.new(payload)
        )
    end
  end

  ##############################################################################

  @type state :: %{
          :name => atom(),
          :level => Logger.level(),
          :handler => :elastic | :stdout
        }

  @doc false
  @impl :gen_event
  def init(__MODULE__), do: {:ok, configure(__MODULE__)}

  @doc false
  @impl :gen_event
  def handle_event(:flush, state), do: {:ok, state}

  @doc false
  @impl :gen_event
  def handle_event(
        {level, group_leader, {Logger, message, timestamp, metadata}},
        %{level: _min_level, handler: handler} = state
      ) do
    {metadata, payload} =
      Keyword.split(metadata, [:module, :function, :file, :line, :context, :pid])

    timestamp = fix_timestamp(timestamp)

    metadata
    |> Keyword.put(:group_leader, inspect(group_leader))
    |> Keyword.put(:timestamp, timestamp)
    |> Logger.metadata()

    payload =
      payload
      |> Keyword.put(:timestamp, timestamp)
      |> Keyword.put(:handler, handler)

    tm(level, group_leader, message, payload)

    {:ok, state}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, %{name: name} = state) do
    cfg = configure(name, opts, state)
    {:ok, cfg, cfg}
  end

  ##############################################################################

  @spec configure(name :: atom(), opts :: keyword(), state :: map()) :: state()
  defp configure(name, opts \\ [], state \\ %{}) when is_map(state) do
    base_level = Application.get_env(:logger, :level, :debug)

    opts =
      :gelato
      |> Application.get_all_env()
      |> Keyword.merge(opts)
      |> Map.new()

    state
    |> Map.merge(opts)
    |> Map.put_new(:name, name)
    |> Map.put_new(:level, base_level)
    |> Map.put_new(:handler, :elastic)
  end

  ##############################################################################
  @spec process_info(pid :: pid(), process_info :: true | any()) :: map() | any()
  defp process_info(pid, true) do
    pid
    |> Process.info()
    |> Kernel.||([])
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
    |> Map.update(:garbage_collection, %{}, &Map.new/1)
    |> Map.put(:schedulers, System.schedulers())
  end

  defp process_info(_pid, process_info), do: process_info

  ##############################################################################

  @spec fix_timestamp(timestamp :: nil | :calendar.datetime()) :: binary()
  @doc false
  defp fix_timestamp(nil),
    do: DateTime.utc_now() |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()

  defp fix_timestamp({{_, _, _} = d, {h, m, s, ms}}) do
    with {:ok, timestamp} <- NaiveDateTime.from_erl({d, {h, m, s}}, {ms * 1_000, 3}),
         result <- NaiveDateTime.to_iso8601(timestamp) do
      "#{result}Z"
    end
  end
end
