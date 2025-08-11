defmodule EthercatEx.MasterTest do
  use ExUnit.Case, async: true

  describe "add_slave_config/2" do
    test "ok" do
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
    end
  end
end
