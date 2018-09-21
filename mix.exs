defmodule GenBrowser.MixProject do
  use Mix.Project

  def project do
    [
      app: :gen_browser,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GenBrowser.Application, []}
    ]
  end

  defp deps do
    [
      {:ace, "~> 0.17.0"},
      {:server_sent_event, "~> 0.4.2"},
      {:jason, "~> 1.0"},
      {:exsync, "~> 0.2.3", only: :dev}
    ]
  end
end
