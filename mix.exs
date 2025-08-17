defmodule Telnyx.MixProject do
  use Mix.Project

  @version "1.0.0"
  @description "Modern Elixir client for the Telnyx SMS API"
  @source_url "https://github.com/ringofhealth/telnyx_client"

  def project do
    [
      app: :telnyx,
      version: @version,
      elixir: "~> 1.12",
      description: @description,
      source_url: @source_url,
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Telnyx.Application, []}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Ring of Health Team"],
      links: %{github: @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp deps do
    [
      {:finch, "~> 0.18.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Telnyx",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end