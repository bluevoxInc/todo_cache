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
    if Mix.env == :test do
      [
        applications: [:logger, :cowboy, :plug, :mnesia, :swarm],
        mod: {Todo.Application, []},
        env: []
      ]
    else
      [
        applications: [:libcluster, :logger, :cowboy, :plug, :mnesia, :swarm, :reunion],
        mod: {Todo.Application, []},
        env: []
      ]
    end
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
      {:cowboy, "~> 1.0.4"},
      {:plug, "~> 1.3.0"},
      {:libcluster, "~> 2.0"},
      {:swarm, "~> 3.0"},
      {:reunion, git: "https://github.com/snar/reunion.git"},
      {:vector_clock, git: "https://github.com/sschneider1207/vector_clock.git"},
      {:meck, "~> 0.8.3", only: :test},
      {:httpoison, "~> 0.10.0", only: :test}
    ]
  end
end
