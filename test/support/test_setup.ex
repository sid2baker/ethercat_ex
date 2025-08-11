defmodule EthercatEx.TestSetup do
  use ExUnit.CaseTemplate

  # FAKE_EC_NAME=FakeEtherCAT is default
  @master_location Path.join(System.tmp_dir!(), "FakeEtherCAT")

  setup_all do
    File.mkdir_p!(@master_location)

    on_exit(fn ->
      nil
      # File.rm_rf!(@master_location)
    end)

    :ok
  end
end
