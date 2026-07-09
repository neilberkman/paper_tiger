defmodule Hackney1xSmoke.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :hackney_1x_smoke,
      version: "0.1.0",
      elixir: "~> 1.16",
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Pinning hackney to the 1.x line forces resolution down the `~> 1.24`
  # branch of paper_tiger's constraint — the branch the main repo can never
  # exercise because its test-only stripity_stripe dep requires hackney 4.x.
  defp deps do
    [
      {:paper_tiger, path: "../.."},
      {:hackney, "~> 1.24"}
    ]
  end
end
