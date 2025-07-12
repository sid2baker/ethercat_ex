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

  test "get version" do
    version = EthercatEx.Nif.version_magic()
    assert is_integer(version)
  end

  test "create master" do
    master = EthercatEx.Nif.request_master()
    assert is_reference(master)
  end

  test "adding domain" do
    master = EthercatEx.Nif.request_master()
    domain = EthercatEx.Nif.master_create_domain(master)
    assert is_reference(master)
    assert is_reference(domain)
  end
end
