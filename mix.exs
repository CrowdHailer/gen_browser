defmodule GenBrowser.MixProject do
  use Mix.Project

  def project do
    [
      app: :gen_browser,
      version: "0.3.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: [extras: ["README.md"], main: "readme"],
      package: package()
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
      {:ok, "~> 2.0.0"},
      {:plug_cowboy, "~> 2.0.0", only: :test},
      {:exsync, "~> 0.2.3", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Give clients/browser an identifier that can be used to send messages to/from/between clients. In essence a pid.
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/crowdhailer/gen_browser"}
    ]
  end
end
