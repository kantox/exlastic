defmodule ExlasticTest do
  use ExUnit.Case
  doctest Exlastic

  test "greets the world" do
    assert Exlastic.hello() == :world
  end
end
