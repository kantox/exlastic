defmodule Exlastic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Exlastic.Telemetry.Instrumenter

  def start(_type, _args) do
    children = []

    Instrumenter.setup()

    opts = [strategy: :one_for_one, name: Exlastic.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
