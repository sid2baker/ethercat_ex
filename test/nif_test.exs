defmodule EthernetEx.NifTest do
  use ExUnit.Case

  @master_location Path.join(System.tmp_dir!(), "FakeEtherCAT")

  setup_all do
    File.mkdir_p!(@master_location)

    on_exit(fn ->
      File.rm_rf!(@master_location)
    end)

    :ok
  end

  test "configure" do
    :ok = EthercatEx.Nif.request_master()
    :ok = EthercatEx.Nif.master_create_domain()
    :ok = EthercatEx.Nif.master_slave_config(0, 0, 0x00000002, 0x044C2C52)
    :ok = EthercatEx.Nif.slave_config_pdos(nil)
    :ok = EthercatEx.Nif.master_activate()
  end
end
