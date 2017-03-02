defmodule Todo.Mixfile do
  use Mix.Project

  def project do
    [app: :todo,
     version: "0.2.0",
     elixir: "~> 1.4.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:libcluster, :logger, :gproc, :cowboy, :plug, :mnesia, :swarm, :unsplit],
      mod: {Todo.Application, []},
      env: []
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
      {:gproc, "~> 0.5.0"},
      {:cowboy, "~> 1.0.4"},
      {:plug, "~> 1.3.0"},
      {:libcluster, "~> 2.0"},
      {:swarm, "~> 3.0"},
      {:unsplit, git: "https://github.com/uwiger/unsplit.git"},
      {:meck, "~> 0.8.3", only: :test},
      {:httpoison, "~> 0.10.0", only: :test}
    ]
  end
end
