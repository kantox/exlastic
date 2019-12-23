defmodule Exlastic do
  @moduledoc """
  Documentation for Exlastic.
  """

  require Logger

  @doc """
  Geberic log function.

  ## Examples

      iex> Exlastic.hello()
      :world

  """
  def log do
    Logger.metadata(request_id: "ABCDEF")
    Logger.debug("Starting Application...")
    Logger.info("I should get output twice")
  end
end
