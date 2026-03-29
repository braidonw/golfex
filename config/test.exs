import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used

# In test we don't send emails
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :golfex, Golfex.Mailer, adapter: Swoosh.Adapters.Test

config :golfex, Golfex.Repo,
  database: Path.expand("../golfex_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1,
  journal_mode: :wal,
  busy_timeout: 5000

config :golfex, GolfexWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "hRWns0byfcCvuHt1yrILCfkkCY1QKj2SMoKgnLR01EbAwJ1gVtNNigQGDdKg24MZ",
  server: false

config :golfex, Oban, testing: :inline

# Use Req.Test plug for MiClub HTTP client in tests
config :golfex, :miclub_req_options, plug: {Req.Test, Golfex.MiClub.Client}

# Bypass the MiClub SessionStore in tests (Req.Test expectations are process-owned)
config :golfex, :miclub_session_store, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
