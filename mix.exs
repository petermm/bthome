defmodule BTHome.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/petermm/bthome"

  def project do
    [
      app: :bthome,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      name: "BTHome",
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A comprehensive, type-safe implementation of the BTHome v2 protocol for Elixir.
    Provides serialization and deserialization of sensor data with full validation,
    error handling, and support for all BTHome v2 sensor types.
    """
  end

  defp package do
    [
      name: "bthome",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "BTHome Specification" => "https://bthome.io/"
      },
      maintainers: ["Peter MM"]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end

  defp docs do
    [
      main: "BTHome",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"],
      groups_for_modules: [
        "Core API": [BTHome],
        "Data Structures": [BTHome.Measurement, BTHome.DecodedData, BTHome.Error],
        "Internal Modules": [
          BTHome.Encoder,
          BTHome.Decoder,
          BTHome.Validator,
          BTHome.Objects,
          BTHome.Config
        ]
      ]
    ]
  end
end
