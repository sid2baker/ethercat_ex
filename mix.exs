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
      env: [
        nif_lib_name: nif_lib_name(Mix.env())
      ],
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths(:dev) ++ ["test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp nif_lib_name(:test), do: "fakeethercat_nif"
  defp nif_lib_name(_), do: "ethercat_nif"

  defp deps do
    [
      {:zigler, "~> 0.13.2", runtime: false}
    ]
  end
end
