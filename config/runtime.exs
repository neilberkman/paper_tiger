import Config

# Standalone server configuration. Only relevant to the container image and any
# other `mix release` build; library consumers configure PaperTiger through
# `PaperTiger.start/1` or their own config files.
if config_env() == :prod do
  # Port precedence: PAPER_TIGER_PORT, then PORT (which most PaaS runtimes
  # inject), then the prod.exs default. `PaperTiger.Port` also reads
  # PAPER_TIGER_PORT directly, so both paths resolve to the same value.
  if port = System.get_env("PAPER_TIGER_PORT") || System.get_env("PORT") do
    config :paper_tiger, port: String.to_integer(port)
  end

  # `PaperTiger.Clock` reads :time_mode and :time_multiplier at init.
  case System.get_env("PAPER_TIGER_CLOCK_MODE") do
    nil ->
      :ok

    mode when mode in ~w(real accelerated manual) ->
      config :paper_tiger, time_mode: String.to_atom(mode)

    other ->
      raise """
      PAPER_TIGER_CLOCK_MODE must be one of: real, accelerated, manual.
      Got: #{inspect(other)}
      """
  end

  if multiplier = System.get_env("PAPER_TIGER_CLOCK_MULTIPLIER") do
    config :paper_tiger, time_multiplier: String.to_integer(multiplier)
  end

  # The billing engine advances subscriptions and finalizes invoices on a timer.
  # Off by default: callers driving the clock themselves want to control when
  # billing runs, and a timer racing their assertions is worse than no timer.
  if System.get_env("PAPER_TIGER_BILLING_ENGINE") == "true" do
    config :paper_tiger, billing_engine: true
  end

  if level = System.get_env("PAPER_TIGER_LOG_LEVEL") do
    config :logger, level: String.to_existing_atom(level)
  end
end

# Configure stripity_stripe at runtime
# Uses PaperTiger by default, real Stripe when VALIDATE_AGAINST_STRIPE=true
if config_env() == :test do
  if System.get_env("VALIDATE_AGAINST_STRIPE") == "true" do
    config :stripity_stripe,
      api_key: System.get_env("STRIPE_API_KEY"),
      # stripity_stripe sends the HTTP/1-only Connection header. hackney 4 can
      # negotiate HTTP/2 by default, which Stripe rejects as a protocol error.
      hackney_opts: [protocols: [:http1]]
  else
    config :stripity_stripe, PaperTiger.stripity_stripe_config()
  end
end
