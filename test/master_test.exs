defmodule EthercatEx.MasterTest do
  use EthercatEx.TestSetup

  alias EthercatEx.{Master, Slave}

  describe "add_slave_config/2" do
    test "test normal functionality" do
      {:ok, master} = Master.start_link()
      {:ok, sc} = Slave.Config.create(1, 1, 0xFF11, 0xFF22)
      sc = sc
           |> Slave.Config.add_sync_manager!(2, :input, :disable)
           |> Slave.Config.add_pdo_assignment!(2, 0x1600)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name2", {0x6001, 0x01, 32}, :my_domain)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name3", {0x6002, 0x01, 16}, :my_domain)
           |> Slave.Config.add_sync_manager!(3, :output, :disable)
           |> Slave.Config.add_pdo_assignment!(3, 0x1A00)
           |> Slave.Config.add_pdo_assignment!(3, 0x1A01)
           |> Slave.Config.add_pdo_entry!(3, 0x1A00, "name4", {0x7000, 0x01, 8}, :your_domain)
           |> Slave.Config.add_pdo_entry!(3, 0x1A01, "name5", {0x7010, 0x01, 32}, :your_domain)

      Master.add_slave_config(master, sc)
    end
  end

  describe "start_cyclic_task/0" do
    test "test normal functionality" do
      {:ok, master} = Master.start_link()
      {:ok, sc} = Slave.Config.create(1, 1, 0xFF11, 0xFF22)
      sc = sc
           |> Slave.Config.add_sync_manager!(2, :input, :disable)
           |> Slave.Config.add_pdo_assignment!(2, 0x1600)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name2", {0x6001, 0x01, 32}, :my_domain)
           |> Slave.Config.add_pdo_entry!(2, 0x1600, "name3", {0x6002, 0x01, 16}, :my_domain)
           |> Slave.Config.add_sync_manager!(3, :output, :disable)
           |> Slave.Config.add_pdo_assignment!(3, 0x1A00)
           |> Slave.Config.add_pdo_assignment!(3, 0x1A01)
           |> Slave.Config.add_pdo_entry!(3, 0x1A00, "name4", {0x7000, 0x01, 8}, :your_domain)
           |> Slave.Config.add_pdo_entry!(3, 0x1A01, "name5", {0x7010, 0x01, 32}, :your_domain)

      Master.add_slave_config(master, sc)
      Master.start_cyclic_task(master)
    end
  end
end
