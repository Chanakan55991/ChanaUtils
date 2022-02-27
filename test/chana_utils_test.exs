defmodule ChanaUtilsTest do
  use ExUnit.Case
  doctest ChanaUtils

  test "greets the world" do
    assert ChanaUtils.hello() == :world
  end
end
