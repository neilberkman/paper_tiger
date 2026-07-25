import Config

config :logger, level: :info

# 12111 is stripe-mock's default port, so an existing stripe-mock service
# definition can be repointed at PaperTiger without changing the port anywhere
# else. Override at runtime with PAPER_TIGER_PORT or PORT.
config :paper_tiger, port: 12_111
