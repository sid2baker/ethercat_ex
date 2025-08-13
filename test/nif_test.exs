defmodule EthernetEx.NifTest do
  use ExUnit.Case

  import EthercatEx.TestHelpers

  alias EthercatEx.Nif

  test "get version" do
    version = EthercatEx.Nif.version_magic()
    assert is_integer(version)
  end

  test "create master" do
    master = EthercatEx.Nif.request_master(0)
    assert is_reference(master)
  end

  test "adding domain" do
    master = EthercatEx.Nif.request_master(0)
    domain = EthercatEx.Nif.master_create_domain(master)
    assert is_reference(master)
    assert is_reference(domain)
  end

  test "add domain to released master" do
    master = EthercatEx.Nif.request_master(0)
    EthercatEx.Nif.release_master(master)
    EthercatEx.Nif.master_create_domain(master)
  end

  test "release already released master" do
    master = EthercatEx.Nif.request_master(0)
    EthercatEx.Nif.release_master(master)
    EthercatEx.Nif.release_master(master)
  end

  test "get slave info" do
    master = Nif.request_master(0)
    slave_info = Nif.master_get_slave(master, 0)
    assert slave_info.alias == 0
  end

  test "create slave config" do
    master = Nif.request_master(0)
    Nif.master_slave_config(master, 0, 0, 0xFF11, 0xFF22)

    Nif.master_slave_config(master, 0, 0, 0xFF11, 0xFF23)
    |> IO.inspect()
  end

  test "test" do
    master = Nif.request_master(0)
    domain = Nif.master_create_domain(master)

    # input card
    alias = 0
    slave_pos = 0
    sync_index = 2
    pdo_index = 0x1A00
    entry_index = 0x6000
    entry_subindex = 0x00
    entry_bit_length = 1
    # EC_DIR_INPUT
    direction = 2
    # EC_WD_DEFAULT
    watchdog = 0

    sc = Nif.master_slave_config(master, alias, slave_pos, 0xFF11, 0xFF22)

    Nif.slave_config_sync_manager(sc, sync_index, direction, watchdog)

    Nif.slave_config_pdo_assign_clear(sc, sync_index)
    Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, entry_bit_length)

    offset =
      Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    Nif.master_activate(master)
    Nif.cyclic_task(self(), master, [domain], [sc])
  end
end
