defmodule Exlastic.Logger.Backend do
  @moduledoc """
  Logger backend to send logs to `ElasticSearch` engine with a telemetry attached.

  Log events are coming in the following format:

  ```
  { log_level, group_leader, {Logger, message, timestamp, metadata} }
  ```
  """

  @behaviour :gen_event
  # import Tirexs.HTTP

  @uri Application.get_env(:exlastic, :uri, "http://127.0.0.1:9200")

  @spec maybe_log(min_level :: Logger.level(), level :: Logger.level(), keyword()) :: :ok | any()
  defmacrop maybe_log(min_level, level, do: block) do
    quote do
      min_level = Application.get_env(:logger, :compile_time_purge_level, unquote(min_level))

      if Logger.Config.compare_levels(unquote(level), unquote(min_level)) != :lt,
        do: unquote(block),
        else: :ok
    end
  end

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
        {level, _group_leader, {Logger, message, timestamp, metadata}},
        %{level: min_level, handler: handler} = state
      ) do
    maybe_log min_level, level do
      item = Exlastic.Logger.Item.create(timestamp, level, message, metadata)

      Logger.metadata(item.metadata)

      case handler do
        :elastic ->
          json =
            item
            |> Map.take([:timestamp, :context, :level])
            |> Map.put(:telemetry, item.message.measurements)
            |> Jason.encode!()
            |> :erlang.binary_to_list()

          :httpc.request(
            :post,
            {to_charlist(@uri <> "/#{item.type}/#{item.message.entity}/"), [], 'application/json',
             json},
            [],
            []
          )

        :stdout ->
          IO.puts(
            Exlastic.Logger.Formatter.format(
              item.level,
              item.message,
              item.timestamp,
              item.metadata
            )
          )
      end
    end

    {:ok, state}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, %{name: name} = state),
    do: {:ok, :ok, configure(name, opts, state)}

  ##############################################################################

  @spec configure(name :: atom(), opts :: keyword(), state :: state()) :: state()
  defp configure(name, opts \\ [], state \\ %{}) when is_map(state) do
    base_level = Application.get_env(:logger, :level, :debug)

    opts =
      :logger
      |> Application.get_env(name, opts)
      |> Map.new()

    state
    |> Map.merge(opts)
    |> Map.put_new(:name, name)
    |> Map.put_new(:level, base_level)
    |> Map.put_new(:handler, :elastic)
  end
end
