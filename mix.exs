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
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["mix_clean"]
    ]
  end

  def application do
    [
      env: [
        nif_lib_name: nif_lib_name()
      ],
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths(:dev) ++ ["test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp nif_lib_name do
    if Mix.env() == :test do
      "fakeethercat_nif"
    else
      "ethercat_nif"
    end
  end

  defp deps do
    [
      {:elixir_make, "~> 0.9", runtime: false}
    ]
  end
end
