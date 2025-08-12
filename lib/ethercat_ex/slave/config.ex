defmodule EthercatEx.Slave.Config do
  @moduledoc """
  Module for managing EtherCAT slave configs.

  This module provides functions for creating and managing EtherCAT slave configurations.
  """

  defstruct [:alias, :position, :vendor_id, :product_code, :sync_managers]

  alias EthercatEx.Domain

  @type t :: %__MODULE__{
          alias: non_neg_integer(),
          position: non_neg_integer(),
          vendor_id: non_neg_integer(),
          product_code: non_neg_integer(),
          sync_managers: %{non_neg_integer() => sync_manager()}
        }

  @type sync_manager :: %{
          direction: direction(),
          watchdog_mode: watchdog_mode(),
          pdos: %{non_neg_integer() => [data_object()]}
        }

  @type direction :: :invalid | :input | :output | :count
  @type watchdog_mode :: :default | :enable | :disable

  @type data_object :: %{
          name: String.t(),
          entry: pdo_entry(),
          domain: Domain.name()
        }

  @type pdo_entry :: {entry_index(), entry_subindex(), entry_size()}

  @type entry_index :: non_neg_integer()
  @type entry_subindex :: non_neg_integer()
  @type entry_size :: non_neg_integer()

  @doc """
  Creates a new slave config with sane defaults.

  ## Parameters

    * `vendor_id` - Vendor ID of the slave
    * `product_code` - Product code of the slave

  """
  def create(alias, position, vendor_id, product_code) do
    sc = %__MODULE__{
      alias: alias,
      position: position,
      vendor_id: vendor_id,
      product_code: product_code,
      sync_managers: %{}
    }

    {:ok, sc}
  end

  @doc """
  Adds a new sync manager to the slave config.

  ## Parameters

    * `sc` - The slave config to add the sync manager to
    * `sync_index` - The index of the sync manager
    * `direction` - The direction of the sync manager
    * `watchdog_mode` - The watchdog mode of the sync manager

  """
  @spec add_sync_manager!(t(), integer(), direction(), watchdog_mode()) :: t()
  def add_sync_manager!(sc, sync_index, direction, watchdog_mode) do
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
  @spec add_pdo_assignment!(t(), non_neg_integer(), non_neg_integer()) :: t()
  def add_pdo_assignment!(%{sync_managers: sync_managers} = sc, sync_index, pdo_index) do
    sync_managers = update_in(sync_managers, [sync_index, :pdos], &Map.put(&1, pdo_index, []))
    %{sc | sync_managers: sync_managers}
  end

  @doc """
  Adds a new PDO entry to the slave config. And maps it to the domain.

  ## Parameters

    * `sc` - The slave config to add the PDO entry to
    * `sync_index` - The index of the sync manager
    * `pdo_index` - The index of the PDO
    * `name` - The name of the PDO entry
    * `pdo_entry` - The PDO entry
    * `domain` - The domain of the PDO entry

  """
  @spec add_pdo_entry!(t(), non_neg_integer(), non_neg_integer(), String.t(), pdo_entry()) :: t()
  def add_pdo_entry!(
        %{sync_managers: sync_managers} = sc,
        sync_index,
        pdo_index,
        name,
        pdo_entry,
        domain \\ nil
      ) do
    sync_managers =
      update_in(sync_managers, [sync_index, :pdos, pdo_index], fn pdo ->
        pdo ++ [%{name: name, entry: pdo_entry, domain: domain}]
      end)

    %{sc | sync_managers: sync_managers}
  end
end
