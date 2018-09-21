defmodule GenBrowser.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {GenBrowser.Server, [%{}, []]},
      {MyLogger, []},
      {PairUp, []},
      %{
        id: GenBrowser.Page.Supervisor,
        start:
          {Supervisor, :start_link,
           [[], [strategy: :one_for_one, name: GenBrowser.Page.Supervisor]]}
      }
    ]

    opts = [strategy: :one_for_one, name: GenBrowser.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
