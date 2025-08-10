defmodule EthercatEx.TestHelpers do
  alias EthercatEx.Nif
  def create_input_card(sc, domain) do
    sync_index = 2
    direction = 1 # Output
    watchdog = 0 # Disabled
    pdo_index = 0x1A00
    entry_index = 0x6000
    entry_subindex = 0x01
    entry_bit_length = 16

    Nif.slave_config_sync_manager(sc, sync_index, direction, watchdog)

    Nif.slave_config_pdo_assign_clear(sc, sync_index)
    Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, entry_bit_length)
    Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
  end

  def create_output_card(sc, domain) do
    sync_index = 3
    direction = 2 # Input
    watchdog = 0 # Disabled
    pdo_index = 0x1600
    entry_index = 0x7000
    entry_subindex = 0x01
    entry_bit_length = 1

    Nif.slave_config_sync_manager(sc, sync_index, direction, watchdog)

    Nif.slave_config_pdo_assign_clear(sc, sync_index)
    Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, entry_bit_length)
    Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
  end
end
