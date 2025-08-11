defmodule EthercatEx.SlaveConfigTest do
  use ExUnit.Case, async: true

  alias EthercatEx.SlaveConfig

  describe "create/2" do
    test "creates a new slave config with vendor_id and product_code" do
      {:ok, sc} = SlaveConfig.create(0xFF11, 0xFF22)

      assert sc.vendor_id == 0xFF11
      assert sc.product_code == 0xFF22
      assert sc.sync_managers == %{}
    end

    test "creates a slave config with different vendor and product codes" do
      {:ok, sc} = SlaveConfig.create(0x1234, 0x5678)

      assert sc.vendor_id == 0x1234
      assert sc.product_code == 0x5678
    end

    test "creates a slave config with zero values" do
      {:ok, sc} = SlaveConfig.create(0, 0)

      assert sc.vendor_id == 0
      assert sc.product_code == 0
    end
  end

  describe "add_sync_manager!/4" do
    setup do
      {:ok, sc} = SlaveConfig.create(0xFF11, 0xFF22)
      {:ok, sc: sc}
    end

    test "adds a new sync manager with default watchdog mode", %{sc: sc} do
      updated_sc = SlaveConfig.add_sync_manager!(sc, 0, :input)

      assert Map.has_key?(updated_sc.sync_managers, 0)
      sync_manager = updated_sc.sync_managers[0]
      assert sync_manager.direction == :input
      assert sync_manager.watchdog_mode == :default
      assert sync_manager.pdos == %{}
    end

    test "adds a sync manager with custom watchdog mode", %{sc: sc} do
      updated_sc = SlaveConfig.add_sync_manager!(sc, 1, :output, :enable)

      sync_manager = updated_sc.sync_managers[1]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
      assert sync_manager.pdos == %{}
    end

    test "adds multiple sync managers", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_sync_manager!(0, :input, :default)
        |> SlaveConfig.add_sync_manager!(1, :output, :enable)
        |> SlaveConfig.add_sync_manager!(2, :input, :disable)

      assert map_size(updated_sc.sync_managers) == 3
      assert updated_sc.sync_managers[0].direction == :input
      assert updated_sc.sync_managers[1].direction == :output
      assert updated_sc.sync_managers[2].direction == :input
      assert updated_sc.sync_managers[2].watchdog_mode == :disable
    end

    test "overwrites existing sync manager at same index", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_sync_manager!(0, :input, :default)
        |> SlaveConfig.add_sync_manager!(0, :output, :enable)

      assert map_size(updated_sc.sync_managers) == 1
      sync_manager = updated_sc.sync_managers[0]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
    end
  end

  describe "add_pdo_assignment!/3" do
    setup do
      {:ok, sc} = SlaveConfig.create(0xFF11, 0xFF22)
      sc = SlaveConfig.add_sync_manager!(sc, 0, :input)
      {:ok, sc: sc}
    end

    test "adds a PDO assignment to existing sync manager", %{sc: sc} do
      updated_sc = SlaveConfig.add_pdo_assignment!(sc, 0, 0x1600)

      sync_manager = updated_sc.sync_managers[0]
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert sync_manager.pdos[0x1600] == []
    end

    test "adds multiple PDO assignments to same sync manager", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_pdo_assignment!(0, 0x1600)
        |> SlaveConfig.add_pdo_assignment!(0, 0x1601)
        |> SlaveConfig.add_pdo_assignment!(0, 0x1602)

      sync_manager = updated_sc.sync_managers[0]
      assert map_size(sync_manager.pdos) == 3
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert Map.has_key?(sync_manager.pdos, 0x1601)
      assert Map.has_key?(sync_manager.pdos, 0x1602)
    end

    test "adds PDO assignments to different sync managers", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_sync_manager!(1, :output)
        |> SlaveConfig.add_pdo_assignment!(0, 0x1600)
        |> SlaveConfig.add_pdo_assignment!(1, 0x1A00)

      assert Map.has_key?(updated_sc.sync_managers[0].pdos, 0x1600)
      assert Map.has_key?(updated_sc.sync_managers[1].pdos, 0x1A00)
    end
  end

  describe "add_pdo_entry!/6" do
    setup do
      {:ok, sc} = SlaveConfig.create(0xFF11, 0xFF22)

      sc =
        sc
        |> SlaveConfig.add_sync_manager!(0, :input)
        |> SlaveConfig.add_pdo_assignment!(0, 0x1600)

      {:ok, sc: sc}
    end

    test "adds a PDO entry to existing PDO", %{sc: sc} do
      updated_sc = SlaveConfig.add_pdo_entry!(sc, 0, 0x1600, 0x6000, 0x01, 8)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 1
      assert {0x6000, 0x01, 8} in pdo_entries
    end

    test "adds multiple PDO entries to same PDO", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x6000, 0x02, 16)
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x1601, 0x01, 32)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 3
      assert {0x6000, 0x01, 8} in pdo_entries
      assert {0x6000, 0x02, 16} in pdo_entries
      assert {0x1601, 0x01, 32} in pdo_entries
    end

    test "preserves order of PDO entries", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x6000, 0x02, 16)
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x1601, 0x01, 32)

      pdo_entries = updated_sc.sync_managers[0].pdos[0x1600]

      expected_entries = [
        {0x6000, 0x01, 8},
        {0x6000, 0x02, 16},
        {0x1601, 0x01, 32}
      ]

      assert pdo_entries == expected_entries
    end

    test "adds entries to different PDOs", %{sc: sc} do
      updated_sc =
        sc
        |> SlaveConfig.add_pdo_assignment!(0, 0x1601)
        |> SlaveConfig.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
        |> SlaveConfig.add_pdo_entry!(0, 0x1601, 0x6010, 0x01, 16)

      pdo_entries_1600 = updated_sc.sync_managers[0].pdos[0x1600]
      pdo_entries_1601 = updated_sc.sync_managers[0].pdos[0x1601]

      assert length(pdo_entries_1600) == 1
      assert length(pdo_entries_1601) == 1
      assert {0x6000, 0x01, 8} in pdo_entries_1600
      assert {0x6010, 0x01, 16} in pdo_entries_1601
    end
  end

  describe "complex slave config setup" do
    test "creates a complete slave config" do
      {:ok, sc} = SlaveConfig.create(0x1234, 0x5678)

      sc =
        sc
        |> SlaveConfig.add_sync_manager!(2, :input, :enable)
        |> SlaveConfig.add_pdo_assignment!(2, 0x1600)
        |> SlaveConfig.add_pdo_entry!(2, 0x1600, 0x6000, 0x01, 8)
        |> SlaveConfig.add_pdo_entry!(2, 0x1600, 0x6000, 0x02, 16)

      sc =
        sc
        |> SlaveConfig.add_sync_manager!(3, :output, :disable)
        |> SlaveConfig.add_pdo_assignment!(3, 0x1A00)
        |> SlaveConfig.add_pdo_assignment!(3, 0x1A01)
        |> SlaveConfig.add_pdo_entry!(3, 0x1A00, 0x7000, 0x01, 8)
        |> SlaveConfig.add_pdo_entry!(3, 0x1A01, 0x7010, 0x01, 32)

      assert sc.vendor_id == 0x1234
      assert sc.product_code == 0x5678
      assert map_size(sc.sync_managers) == 2

      input_sm = sc.sync_managers[2]
      assert input_sm.direction == :input
      assert input_sm.watchdog_mode == :enable
      assert map_size(input_sm.pdos) == 1
      assert length(input_sm.pdos[0x1600]) == 2

      output_sm = sc.sync_managers[3]
      assert output_sm.direction == :output
      assert output_sm.watchdog_mode == :disable
      assert map_size(output_sm.pdos) == 2
      assert length(output_sm.pdos[0x1A00]) == 1
      assert length(output_sm.pdos[0x1A01]) == 1
    end
  end

  describe "edge cases" do
    test "handles zero values in PDO entries" do
      {:ok, sc} = SlaveConfig.create(0xFF11, 0xFF22)

      sc =
        sc
        |> SlaveConfig.add_sync_manager!(0, :input)
        |> SlaveConfig.add_pdo_assignment!(0, 0)
        |> SlaveConfig.add_pdo_entry!(0, 0, 0, 0, 0)

      pdo_entries = sc.sync_managers[0].pdos[0]
      assert {0, 0, 0} in pdo_entries
    end

    test "handles maximum values" do
      {:ok, sc} = SlaveConfig.create(0xFFFFFFFF, 0xFFFFFFFF)

      sc =
        sc
        |> SlaveConfig.add_sync_manager!(255, :output)
        |> SlaveConfig.add_pdo_assignment!(255, 0xFFFF)
        |> SlaveConfig.add_pdo_entry!(255, 0xFFFF, 0xFFFF, 0xFF, 0xFFFF)

      assert sc.vendor_id == 0xFFFFFFFF
      assert sc.product_code == 0xFFFFFFFF
      pdo_entries = sc.sync_managers[255].pdos[0xFFFF]
      assert {0xFFFF, 0xFF, 0xFFFF} in pdo_entries
    end
  end
end
