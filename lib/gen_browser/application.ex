defmodule GenBrowser.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: GenBrowser.MailboxSupervisor}
    ]

    opts = [strategy: :one_for_one, name: GenBrowser.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
