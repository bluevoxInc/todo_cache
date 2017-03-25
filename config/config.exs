# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
config :todo, port: 5454
config :libcluster,
  topologies: [
    todo_cluster: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: [:"n1@192.168.1.12", :"n2@192.168.1.12", :"n3@192.168.1.14", :"n4@192.168.1.14"]],
      # The function to use for connecting nodes. The node
      # name will be appended to the argument list. Optional
      connect: {:net_kernel, :connect, []},
      # The function to use for disconnecting nodes. The node
      # name will be appended to the argument list. Optional
      disconnect: {:net_kernel, :disconnect, []},
      # A list of options for the supervisor child spec
      # of the selected strategy. Optional
      child_spec: [restart: :transient]
    ]
  ]
#
# And access this configuration in your application as:
#
#     Application.get_env(:todo, :key)
#
# Or configure a 3rd-party app:
#
config :logger, 
  handle_otp_reports: true,
  handle_sasl_reports: false,
  backends: [:console],
  compile_time_purge_level: :debug,  #purges at compilation time all calls that have log level lower than the value of this option.
  level: :info

config :logger, :console, 
  format: "$time $level $node $metadata $levelpad$message\n", 
  metadata: [:module, :function, :line],
  colors: [info: :black]
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
