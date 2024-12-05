defmodule EthernetEx.NifTest do
  use ExUnit.Case

  # FAKE_EC_NAME=FakeEtherCAT is default
  @master_location Path.join(System.tmp_dir!(), "FakeEtherCAT")

  setup_all do
    File.mkdir_p!(@master_location)

    on_exit(fn ->
      File.rm_rf!(@master_location)
    end)

    :ok
  end

  test "adding domain" do
    :ok = EthercatEx.Nif.request_master(self())
    :ok = EthercatEx.Nif.master_create_domain(~c"test")
    :ok = EthercatEx.Nif.master_remove_domain(~c"test")
  end

  test "remove not added domain" do
    :ok = EthercatEx.Nif.request_master(self())
    :error = EthercatEx.Nif.master_remove_domain(~c"test")
  end
end
