defmodule EthercatEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :ethercat_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:muontrap, "~> 1.0"}
    ]
  end
end
