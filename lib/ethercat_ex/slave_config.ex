defmodule EthercatEx.SlaveConfig do
  @moduledoc """
  Module for managing EtherCAT slaves.

  This module provides functions for configuring slaves, managing PDO mappings,
  sync managers, and handling slave-specific operations.
  """

  defstruct [:vendor_id, :product_code, :sync_managers]

  @type __MODULE__ :: %{
          vendor_id: non_neg_integer(),
          product_code: non_neg_integer(),
          sync_managers: %{non_neg_integer() => sync_manager()}
        }

  @type sync_manager :: %{
          direction: :input | :output,
          watchdog_mode: :default | :enable | :disable,
          pdos: %{non_neg_integer() => [pdo_entry()]}
        }

  @type pdo_entry :: {entry_index(), entry_subindex(), entry_size()}

  @type entry_index :: non_neg_integer()
  @type entry_subindex :: non_neg_integer()
  @type entry_size :: non_neg_integer()

  # AL State constants from EtherCAT specification
  @al_state_init 0x01
  @al_state_preop 0x02
  @al_state_safeop 0x04
  @al_state_op 0x08

  @doc """
  Creates a new slave with sane defaults.

  ## Parameters

    * `vendor_id` - Vendor ID of the slave
    * `product_code` - Product code of the slave

  """
  def create(vendor_id, product_code) do
    sc = %__MODULE__{
      vendor_id: vendor_id,
      product_code: product_code,
      sync_managers: %{}
    }

    {:ok, sc}
  end

  @doc """
  Adds a new sync manager to the slave.

  ## Parameters

    * `sc` - The slave config to add the sync manager to
    * `sync_index` - The index of the sync manager
    * `direction` - The direction of the sync manager
    * `watchdog_mode` - The watchdog mode of the sync manager

  """
  def add_sync_manager!(sc, sync_index, direction, watchdog_mode \\ :default) do
    sync_managers =
      Map.put(sc.sync_managers, sync_index, %{
        direction: direction,
        watchdog_mode: watchdog_mode,
        pdos: %{}
      })

    %{sc | sync_managers: sync_managers}
  end

  @doc """
  Adds a new PDO assignment to the slave config.

  ## Parameters

    * `sc` - The slave config to add the PDO assignment to
    * `sync_index` - The index of the sync manager
    * `pdo_index` - The index of the PDO

  """
  def add_pdo_assignment!(%{sync_managers: sync_managers} = sc, sync_index, pdo_index) do
    sync_managers = update_in(sync_managers, [sync_index, :pdos], &Map.put(&1, pdo_index, []))
    %{sc | sync_managers: sync_managers}
  end

  @doc """
  Adds a new PDO entry to the slave config.

  ## Parameters

    * `sc` - The slave config to add the PDO entry to
    * `sync_index` - The index of the sync manager
    * `pdo_index` - The index of the PDO
    * `entry_index` - The index of the entry
    * `entry_subindex` - The subindex of the entry
    * `entry_size` - The size of the entry

  """
  def add_pdo_entry!(
        %{sync_managers: sync_managers} = sc,
        sync_index,
        pdo_index,
        entry_index,
        entry_subindex,
        entry_size
      ) do
    sync_managers =
      update_in(sync_managers, [sync_index, :pdos, pdo_index], fn pdo ->
        pdo ++ [{entry_index, entry_subindex, entry_size}]
      end)

    %{sc | sync_managers: sync_managers}
  end
end
