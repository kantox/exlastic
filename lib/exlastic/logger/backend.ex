defmodule Exlastic.Logger.Backend do
  @moduledoc false

  @behaviour :gen_event
  alias Exlastic.Logger.{Formatter, Item}

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
      Task.async(fn ->
        item = Item.create(timestamp, level, message, metadata)

        Logger.metadata(item.metadata)

        case handler do
          :elastic ->
            json =
              item
              |> Map.take([:timestamp, :context, :level])
              |> Map.put(:entity, item.message.entity)
              |> Map.put(:telemetry, item.message.measurements)
              |> Jason.encode!()
              |> :erlang.binary_to_list()

            uuid = Exlastic.UUID.generate()

            case :httpc.request(
                   :post,
                   {to_charlist(@uri <> "/#{item.type}/_create/#{uuid}"), [], 'application/json',
                    json},
                   [],
                   []
                 ) do
              {:ok, {{'HTTP/1.1', 201, 'Created'}, resp, _}} ->
                [id] = for {'location', id} <- resp, do: id

                IO.puts(
                  Formatter.format(
                    :debug,
                    %{ok: to_string(id)},
                    item.timestamp,
                    item.metadata
                  )
                )

              error ->
                IO.puts(
                  Formatter.format(
                    :warn,
                    %{error: inspect(error)},
                    item.timestamp,
                    item.metadata
                  )
                )
            end

          :stdout ->
            IO.puts(
              Formatter.format(
                item.level,
                %{message: item.message, context: item.context},
                item.timestamp,
                item.metadata
              )
            )
        end
      end)
    end

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
      :exlastic
      |> Application.get_all_env()
      |> Keyword.merge(opts)
      |> Map.new()

    state
    |> Map.merge(opts)
    |> Map.put_new(:name, name)
    |> Map.put_new(:level, base_level)
    |> Map.put_new(:handler, :elastic)
  end
end
