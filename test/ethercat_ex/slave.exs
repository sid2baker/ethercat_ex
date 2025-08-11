defmodule EthercatEx.SlaveTest do
  use ExUnit.Case, async: true

  alias EthercatEx.Slave

  describe "create/2" do
    test "creates a new slave with vendor_id and product_code" do
      {:ok, slave} = Slave.create(0xFF11, 0xFF22)

      assert slave.vendor_id == 0xFF11
      assert slave.product_code == 0xFF22
      assert slave.sync_managers == %{}
    end

    test "creates a slave with different vendor and product codes" do
      {:ok, slave} = Slave.create(0x1234, 0x5678)

      assert slave.vendor_id == 0x1234
      assert slave.product_code == 0x5678
    end

    test "creates a slave with zero values" do
      {:ok, slave} = Slave.create(0, 0)

      assert slave.vendor_id == 0
      assert slave.product_code == 0
    end
  end

  describe "add_sync_manager!/4" do
    setup do
      {:ok, slave} = Slave.create(0xFF11, 0xFF22)
      {:ok, slave: slave}
    end

    test "adds a new sync manager with default watchdog mode", %{slave: slave} do
      updated_slave = Slave.add_sync_manager!(slave, 0, :input)

      assert Map.has_key?(updated_slave.sync_managers, 0)
      sync_manager = updated_slave.sync_managers[0]
      assert sync_manager.direction == :input
      assert sync_manager.watchdog_mode == :default
      assert sync_manager.pdos == %{}
    end

    test "adds a sync manager with custom watchdog mode", %{slave: slave} do
      updated_slave = Slave.add_sync_manager!(slave, 1, :output, :enable)

      sync_manager = updated_slave.sync_managers[1]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
      assert sync_manager.pdos == %{}
    end

    test "adds multiple sync managers", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_sync_manager!(0, :input, :default)
                     |> Slave.add_sync_manager!(1, :output, :enable)
                     |> Slave.add_sync_manager!(2, :input, :disable)

      assert map_size(updated_slave.sync_managers) == 3
      assert updated_slave.sync_managers[0].direction == :input
      assert updated_slave.sync_managers[1].direction == :output
      assert updated_slave.sync_managers[2].direction == :input
      assert updated_slave.sync_managers[2].watchdog_mode == :disable
    end

    test "overwrites existing sync manager at same index", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_sync_manager!(0, :input, :default)
                     |> Slave.add_sync_manager!(0, :output, :enable)

      assert map_size(updated_slave.sync_managers) == 1
      sync_manager = updated_slave.sync_managers[0]
      assert sync_manager.direction == :output
      assert sync_manager.watchdog_mode == :enable
    end
  end

  describe "add_pdo_assignment!/3" do
    setup do
      {:ok, slave} = Slave.create(0xFF11, 0xFF22)
      slave = Slave.add_sync_manager!(slave, 0, :input)
      {:ok, slave: slave}
    end

    test "adds a PDO assignment to existing sync manager", %{slave: slave} do
      updated_slave = Slave.add_pdo_assignment!(slave, 0, 0x1600)

      sync_manager = updated_slave.sync_managers[0]
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert sync_manager.pdos[0x1600] == []
    end

    test "adds multiple PDO assignments to same sync manager", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_pdo_assignment!(0, 0x1600)
                     |> Slave.add_pdo_assignment!(0, 0x1601)
                     |> Slave.add_pdo_assignment!(0, 0x1602)

      sync_manager = updated_slave.sync_managers[0]
      assert map_size(sync_manager.pdos) == 3
      assert Map.has_key?(sync_manager.pdos, 0x1600)
      assert Map.has_key?(sync_manager.pdos, 0x1601)
      assert Map.has_key?(sync_manager.pdos, 0x1602)
    end

    test "adds PDO assignments to different sync managers", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_sync_manager!(1, :output)
                     |> Slave.add_pdo_assignment!(0, 0x1600)
                     |> Slave.add_pdo_assignment!(1, 0x1A00)

      assert Map.has_key?(updated_slave.sync_managers[0].pdos, 0x1600)
      assert Map.has_key?(updated_slave.sync_managers[1].pdos, 0x1A00)
    end
  end

  describe "add_pdo_entry!/6" do
    setup do
      {:ok, slave} = Slave.create(0xFF11, 0xFF22)
      slave = slave
              |> Slave.add_sync_manager!(0, :input)
              |> Slave.add_pdo_assignment!(0, 0x1600)
      {:ok, slave: slave}
    end

    test "adds a PDO entry to existing PDO", %{slave: slave} do
      updated_slave = Slave.add_pdo_entry!(slave, 0, 0x1600, 0x6000, 0x01, 8)

      pdo_entries = updated_slave.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 1
      assert {0x6000, 0x01, 8} in pdo_entries
    end

    test "adds multiple PDO entries to same PDO", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6000, 0x02, 16)
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6001, 0x01, 32)

      pdo_entries = updated_slave.sync_managers[0].pdos[0x1600]
      assert length(pdo_entries) == 3
      assert {0x6000, 0x01, 8} in pdo_entries
      assert {0x6000, 0x02, 16} in pdo_entries
      assert {0x6001, 0x01, 32} in pdo_entries
    end

    test "preserves order of PDO entries", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6000, 0x02, 16)
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6001, 0x01, 32)

      pdo_entries = updated_slave.sync_managers[0].pdos[0x1600]
      expected_entries = [
        {0x6000, 0x01, 8},
        {0x6000, 0x02, 16},
        {0x6001, 0x01, 32}
      ]
      assert pdo_entries == expected_entries
    end

    test "adds entries to different PDOs", %{slave: slave} do
      updated_slave = slave
                     |> Slave.add_pdo_assignment!(0, 0x1601)
                     |> Slave.add_pdo_entry!(0, 0x1600, 0x6000, 0x01, 8)
                     |> Slave.add_pdo_entry!(0, 0x1601, 0x6010, 0x01, 16)

      pdo_entries_1600 = updated_slave.sync_managers[0].pdos[0x1600]
      pdo_entries_1601 = updated_slave.sync_managers[0].pdos[0x1601]

      assert length(pdo_entries_1600) == 1
      assert length(pdo_entries_1601) == 1
      assert {0x6000, 0x01, 8} in pdo_entries_1600
      assert {0x6010, 0x01, 16} in pdo_entries_1601
    end
  end

  describe "complex slave configuration" do
    test "creates a complete slave configuration" do
      {:ok, slave} = Slave.create(0x1234, 0x5678)

      # Add input sync manager with PDOs
      slave = slave
              |> Slave.add_sync_manager!(2, :input, :enable)
              |> Slave.add_pdo_assignment!(2, 0x1600)
              |> Slave.add_pdo_entry!(2, 0x1600, 0x6000, 0x01, 8)
              |> Slave.add_pdo_entry!(2, 0x1600, 0x6000, 0x02, 16)

      # Add output sync manager with PDOs
      slave = slave
              |> Slave.add_sync_manager!(3, :output, :disable)
              |> Slave.add_pdo_assignment!(3, 0x1A00)
              |> Slave.add_pdo_assignment!(3, 0x1A01)
              |> Slave.add_pdo_entry!(3, 0x1A00, 0x7000, 0x01, 8)
              |> Slave.add_pdo_entry!(3, 0x1A01, 0x7010, 0x01, 32)

      # Verify the complete configuration
      assert slave.vendor_id == 0x1234
      assert slave.product_code == 0x5678
      assert map_size(slave.sync_managers) == 2

      # Verify input sync manager
      input_sm = slave.sync_managers[2]
      assert input_sm.direction == :input
      assert input_sm.watchdog_mode == :enable
      assert map_size(input_sm.pdos) == 1
      assert length(input_sm.pdos[0x1600]) == 2

      # Verify output sync manager
      output_sm = slave.sync_managers[3]
      assert output_sm.direction == :output
      assert output_sm.watchdog_mode == :disable
      assert map_size(output_sm.pdos) == 2
      assert length(output_sm.pdos[0x1A00]) == 1
      assert length(output_sm.pdos[0x1A01]) == 1
    end
  end

  describe "edge cases" do
    test "handles zero values in PDO entries" do
      {:ok, slave} = Slave.create(0xFF11, 0xFF22)

      slave = slave
              |> Slave.add_sync_manager!(0, :input)
              |> Slave.add_pdo_assignment!(0, 0)
              |> Slave.add_pdo_entry!(0, 0, 0, 0, 0)

      pdo_entries = slave.sync_managers[0].pdos[0]
      assert {0, 0, 0} in pdo_entries
    end

    test "handles maximum values" do
      {:ok, slave} = Slave.create(0xFFFFFFFF, 0xFFFFFFFF)

      slave = slave
              |> Slave.add_sync_manager!(255, :output)
              |> Slave.add_pdo_assignment!(255, 0xFFFF)
              |> Slave.add_pdo_entry!(255, 0xFFFF, 0xFFFF, 0xFF, 0xFFFF)

      assert slave.vendor_id == 0xFFFFFFFF
      assert slave.product_code == 0xFFFFFFFF
      pdo_entries = slave.sync_managers[255].pdos[0xFFFF]
      assert {0xFFFF, 0xFF, 0xFFFF} in pdo_entries
    end
  end
end
