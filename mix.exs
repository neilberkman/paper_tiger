defmodule PaperTiger.MixProject do
  @moduledoc false
  use Mix.Project

  @version "1.2.2"
  @url "https://github.com/EnaiaInc/paper_tiger"
  @maintainers ["Enaia Inc"]

  def project do
    [
      name: "PaperTiger",
      app: :paper_tiger,
      version: @version,
      elixir: "~> 1.16 or ~> 1.17 or ~> 1.18 or ~> 1.19 or ~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex package
      package: package(),
      description: "A stateful mock Stripe server for testing Elixir applications",
      source_url: @url,
      homepage_url: @url,

      # Docs
      docs: docs(),

      # Quality tooling
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:mix, :ex_unit]
      ],

      # Test coverage
      test_coverage: [tool: ExCoveralls],

      # Treat warnings as errors
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {PaperTiger.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP server
      {:bandit, "~> 1.6"},
      {:plug, "~> 1.16"},

      # HTTP client for webhooks
      {:req, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Optional: hackney for stripity_stripe sandbox integration
      # Users of PaperTiger.StripityStripeHackney must have hackney available.
      # Floor is 1.24: the least-vulnerable 1.x release (SSRF fixed in 1.21.0,
      # pool leak in 1.24.0). Four advisories affecting all of 1.x were only
      # ever fixed in 4.0.1 — prefer hackney 4.x when your dep tree allows it.
      {:hackney, "~> 1.24 or ~> 4.0", optional: true},

      # Testing/dev
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:stripity_stripe, "~> 3.3", only: :test}
    ] ++
      python_sdk_contract_deps() ++
      [
        # Quality tooling
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
        {:ex_doc, "~> 0.35", only: :dev, runtime: false},
        {:quokka, "~> 2.7", only: [:dev, :test], runtime: false},
        {:mix_test_watch, "~> 1.2", only: :dev, runtime: false},
        {:excoveralls, "~> 0.18", only: :test}
      ]
  end

  defp python_sdk_contract_deps do
    if System.get_env("VALIDATE_PYTHON_SDK") == "true" do
      [{:erlang_python, "~> 3.0", only: :test, runtime: false}]
    else
      []
    end
  end

  defp package do
    [
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/paper_tiger/changelog.html",
        "GitHub" => @url
      },
      files:
        ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs) ++
          ~w(examples/getting_started.livemd),
      keywords: [
        "stripe",
        "testing",
        "mock",
        "payments",
        "subscriptions",
        "webhooks",
        "contract-testing",
        "elixir"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @url,
      # PaperTiger.Port is internal (@moduledoc false) but mentioned in the
      # changelog; don't autolink references to it.
      skip_code_autolink_to: &String.match?(&1, ~r/^PaperTiger\.Port(\..*)?$/),
      extras: [
        "README.md",
        "CHANGELOG.md",
        "examples/getting_started.livemd"
      ],
      extra_section: "GUIDES",
      groups_for_extras: [
        Examples: ~r/examples\/.*/,
        Changelog: ~r/CHANGELOG\.md/
      ],
      groups_for_modules: [
        "Public API": [PaperTiger],
        Resources: ~r/PaperTiger\.Resources\..*/,
        Storage: ~r/PaperTiger\.Store\..*/,
        Webhooks: ~r/PaperTiger\.Webhook.*/,
        Testing: ~r/PaperTiger\.Test.*/,
        Internal: ~r/PaperTiger\.(Clock|Router|Error|Plugs|Resource|Idempotency).*/
      ]
    ]
  end
end
