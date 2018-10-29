defmodule GenBrowserTest do
  use ExUnit.Case
  doctest GenBrowser

  test "Client tests" do
    case System.cmd("npm", ["test"], cd: "client") do
      {_, 0} ->
        :ok

      {_output, _code} ->
        flunk("JavaScript testing failed")
    end
  end
end
