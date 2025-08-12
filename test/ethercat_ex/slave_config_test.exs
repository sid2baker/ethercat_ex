defmodule EthercatEx.Slave.ConfigTest do
  use EthercatEx.TestSetup

  alias EthercatEx.Slave.Config

  describe "create/4" do
    test "creates a new slave config with alias, position, vendor_id and product_code" do
      {:ok, sc} = Config.create(1, 1, 0xFF11, 0xFF22)

      assert sc.alias == 1
      assert sc.position == 1
      assert sc.vendor_id == 0xFF11
      assert sc.product_code == 0xFF22
      assert sc.sync_managers == %{}
    end

    test "creates a slave config with different values" do
      {:ok, sc} = Config.create(2, 3, 0x1234, 0x5678)

      assert sc.alias == 2
      assert sc.position == 3
      assert sc.vendor_id == 0x1234
      assert sc.product_code == 0x5678
    end

    test "creates a slave config with zero values" do
      {:ok, sc} = Config.create(0, 0, 0, 0)

      assert sc.alias == 0
      assert sc.position == 0
      assert sc.vendor_id == 0
      assert sc.product_code == 0
    end
  end

  describe "add_sync_manager!/4" do
    setup do
      {:ok, sc} = Config.create(1, 1, 0xFF11, 0xFF22)
      {:ok, sc: sc}
    end

    test "adds a new sync manager with default watchdog mode", %{sc: sc} do
      updated_sc = Config.add_sync_manager!(sc, 0, :input, :default)

      assert Map.has_key?(updated_sc.sync_managers, 0)
      sync_manager = updated_sc.sync_managers[0]
      assert sync_manager.direction == :input
      assert sync_manager.watchdog_mode == :default
      assert sync_manager.pdos == %{}
    end

    test "adds a sync manager with custom watchdog mode", %{sc: sc} do
      updated_sc = Config.add_sync_manager!(sc, 1, :output, :enable)

      sync_manager = updated_sc.sync_managers[1]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
      assert sync_manager.pdos == %{}
    end

    test "adds multiple sync managers", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_sync_manager!(0, :input, :default)
        |> Config.add_sync_manager!(1, :output, :enable)
        |> Config.add_sync_manager!(2, :input, :disable)

      assert map_size(updated_sc.sync_managers) == 3
      assert updated_sc.sync_managers[0].direction == :input
      assert updated_sc.sync_managers[1].direction == :output
      assert updated_sc.sync_managers[2].direction == :input
      assert updated_sc.sync_managers[2].watchdog_mode == :disable
    end

    test "overwrites existing sync manager at same index", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_sync_manager!(0, :input, :default)
        |> Config.add_sync_manager!(0, :output, :enable)

      assert map_size(updated_sc.sync_managers) == 1
      sync_manager = updated_sc.sync_managers[0]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
    end
  end

  describe "add_pdo_assignment!/3" do
    setup do
      {:ok, sc} = Config.create(1, 1, 0xFF11, 0xFF22)
      sc = Config.add_sync_manager!(sc, 0, :input, :default)
      {:ok, sc: sc}
    end

    test "adds a PDO assignment to existing sync manager", %{sc: sc} do
      updated_sc = Config.add_pdo_assignment!(sc, 0, 0x1600)

      sync_manager = updated_sc.sync_managers[0]
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert sync_manager.pdos[0x1600] == []
    end

    test "adds multiple PDO assignments to same sync manager", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_pdo_assignment!(0, 0x1600)
        |> Config.add_pdo_assignment!(0, 0x1601)
        |> Config.add_pdo_assignment!(0, 0x1602)

      sync_manager = updated_sc.sync_managers[0]
      assert map_size(sync_manager.pdos) == 3
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert Map.has_key?(sync_manager.pdos, 0x1601)
      assert Map.has_key?(sync_manager.pdos, 0x1602)
    end

    test "adds PDO assignments to different sync managers", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_sync_manager!(1, :output, :default)
        |> Config.add_pdo_assignment!(0, 0x1600)
        |> Config.add_pdo_assignment!(1, 0x1A00)

      assert Map.has_key?(updated_sc.sync_managers[0].pdos, 0x1600)
      assert Map.has_key?(updated_sc.sync_managers[1].pdos, 0x1A00)
    end
  end

  describe "add_pdo_entry!/6" do
    setup do
      {:ok, sc} = Config.create(1, 1, 0xFF11, 0xFF22)

      sc =
        sc
        |> Config.add_sync_manager!(0, :input, :default)
        |> Config.add_pdo_assignment!(0, 0x1600)

      {:ok, sc: sc}
    end

    test "adds a PDO entry to existing PDO", %{sc: sc} do
      updated_sc = Config.add_pdo_entry!(sc, 0, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 1
      assert %{name: "name1", entry: {0x6000, 0x01, 8}, domain: :my_domain} in pdo_entries
    end

    test "adds multiple PDO entries to same PDO", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_pdo_entry!(0, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)
        |> Config.add_pdo_entry!(0, 0x1600, "name2", {0x6001, 0x01, 32}, :my_domain)
        |> Config.add_pdo_entry!(0, 0x1600, "name3", {0x6002, 0x01, 16}, :my_domain)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 3

      assert %{name: "name1", entry: {0x6000, 0x01, 8}, domain: :my_domain} in pdo_entries
      assert %{name: "name2", entry: {0x6001, 0x01, 32}, domain: :my_domain} in pdo_entries
      assert %{name: "name3", entry: {0x6002, 0x01, 16}, domain: :my_domain} in pdo_entries
    end

    test "preserves order of PDO entries", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_pdo_entry!(0, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)
        |> Config.add_pdo_entry!(0, 0x1600, "name2", {0x6001, 0x01, 32}, :my_domain)
        |> Config.add_pdo_entry!(0, 0x1600, "name3", {0x6002, 0x01, 16}, :my_domain)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]

      expected_entries = [
        %{name: "name1", entry: {0x6000, 0x01, 8}, domain: :my_domain},
        %{name: "name2", entry: {0x6001, 0x01, 32}, domain: :my_domain},
        %{name: "name3", entry: {0x6002, 0x01, 16}, domain: :my_domain}
      ]

      assert pdo_entries == expected_entries
    end

    test "adds entries to different PDOs", %{sc: sc} do
      updated_sc =
        sc
        |> Config.add_pdo_assignment!(0, 0x1601)
        |> Config.add_pdo_entry!(0, 0x1600, "name1", {0x6000, 0x01, 8})
        |> Config.add_pdo_entry!(0, 0x1601, "name2", {0x6010, 0x01, 16})

      pdo_entries_1600 = updated_sc.sync_managers[0].pdos[0x1600]
      pdo_entries_1601 = updated_sc.sync_managers[0].pdos[0x1601]

      assert length(pdo_entries_1600) == 1
      assert length(pdo_entries_1601) == 1
    end
  end
end
