defmodule Palleto.Mixfile do
  use Mix.Project

  def project do
    [app: :palleto,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [
        :ex_aws,
        :gen_stage,
        :hackney,
        :httpoison,
        :logger,
        :poison
      ],
      mod: {Palleto, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_aws, "~> 1.0.0-beta0"},
      {:gen_stage, "~> 0.11.0"},
      {:hackney, "~> 1.6"},
      {:httpoison, "~> 0.9.0"},
      {:poison, "~> 2.0"},
      {:sweet_xml, "~> 0.6.1"}
    ]
  end
end
