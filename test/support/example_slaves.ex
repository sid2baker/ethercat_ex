defmodule EthercatEx.ExampleSlaves do
  alias EthercatEx.{Master, Slave}

  def new() do
    {:ok, master} = Master.start_link(master_index: 999, name: FakeMaster)
    master
    |> create_input_card(0)
    |> create_output_card(1)
  end

  def create_input_card(master, position) do
    {:ok, sc} = Slave.Config.create(0, position, 0xFF11, 0xFF22)

    sc =
      sc
      |> Slave.Config.add_sync_manager!(2, :output, :disable)
      |> Slave.Config.add_pdo_assignment!(2, 0x1600)
      |> Slave.Config.add_pdo_entry!(2, 0x1600, "name1", {0x6000, 0x01, 8}, :my_domain)
      |> Slave.Config.add_pdo_entry!(2, 0x1600, "name2", {0x6001, 0x01, 32}, :my_domain)
      |> Slave.Config.add_pdo_entry!(2, 0x1600, "name3", {0x6002, 0x01, 16}, :my_domain)

    {:ok, _} = Master.add_slave_config(master, sc)
    master
  end

  def create_output_card(master, position) do
    {:ok, sc} = Slave.Config.create(0, position, 0xFF11, 0xFF33)
    sc =
      sc
      |> Slave.Config.add_sync_manager!(3, :input, :disable)
      |> Slave.Config.add_pdo_assignment!(3, 0x1A00)
      |> Slave.Config.add_pdo_assignment!(3, 0x1A01)
      |> Slave.Config.add_pdo_entry!(3, 0x1A00, "name4", {0x7000, 0x01, 8}, :my_domain)
      |> Slave.Config.add_pdo_entry!(3, 0x1A01, "name5", {0x7010, 0x01, 32}, :my_domain)

    {:ok, _} = Master.add_slave_config(master, sc)
    master
  end
end
