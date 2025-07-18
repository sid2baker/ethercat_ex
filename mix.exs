defmodule EthercatEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :ethercat_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(:test), do: elixirc_paths(:dev) ++ ["test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:zigler, "~> 0.14.1", runtime: false}
    ]
  end
end
