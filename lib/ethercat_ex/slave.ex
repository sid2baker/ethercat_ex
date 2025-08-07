defmodule EthercatEx.Slave do
  @moduledoc """
  Module for managing EtherCAT slaves.

  This module provides functions for configuring slaves, managing PDO mappings,
  sync managers, and handling slave-specific operations.
  """

  alias EthercatEx.Nif

  @type slave_config_ref :: reference()
  @type slave_info :: %{
          position: non_neg_integer(),
          vendor_id: non_neg_integer(),
          product_code: non_neg_integer(),
          revision_number: non_neg_integer(),
          serial_number: non_neg_integer(),
          al_state: atom(),
          error_flag: boolean(),
          sync_count: non_neg_integer(),
          sdo_count: non_neg_integer(),
          name: binary()
        }

  @type sync_manager_config :: %{
          index: non_neg_integer(),
          direction: :input | :output,
          watchdog_mode: :default | :enable | :disable
        }

  @type pdo_entry :: %{
          index: non_neg_integer(),
          subindex: non_neg_integer(),
          bit_length: non_neg_integer(),
          name: binary()
        }

  # AL State constants from EtherCAT specification
  @al_state_init 0x01
  @al_state_preop 0x02
  @al_state_safeop 0x04
  @al_state_op 0x08

  @doc """
  Configures a sync manager for a slave.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `sync_index` - Index of the sync manager (0-3)
    * `direction` - Direction (:input for RxPDO, :output for TxPDO)
    * `watchdog_mode` - Watchdog mode (:default, :enable, :disable)

  ## Examples

      iex> EthercatEx.Slave.configure_sync_manager(slave_config, 0, :input, :default)
      :ok
  """
  @spec configure_sync_manager(
          slave_config_ref(),
          non_neg_integer(),
          :input | :output,
          :default | :enable | :disable
        ) :: :ok | {:error, term()}
  def configure_sync_manager(slave_config_ref, sync_index, direction, watchdog_mode) do
    # Convert direction to EtherCAT constant
    ec_direction =
      case direction do
        # EC_DIR_INPUT
        :input -> 2
        # EC_DIR_OUTPUT
        :output -> 1
      end

    # Convert watchdog mode to EtherCAT constant
    ec_watchdog =
      case watchdog_mode do
        # EC_WD_DEFAULT
        :default -> 0
        # EC_WD_ENABLE
        :enable -> 1
        # EC_WD_DISABLE
        :disable -> 2
      end

    Nif.slave_config_sync_manager(slave_config_ref, sync_index, ec_direction, ec_watchdog)
  end

  @doc """
  Clears all PDO assignments for a sync manager.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `sync_index` - Index of the sync manager

  ## Examples

      iex> EthercatEx.Slave.clear_pdo_assignments(slave_config, 0)
      :ok
  """
  @spec clear_pdo_assignments(slave_config_ref(), non_neg_integer()) ::
          :ok | {:error, term()}
  def clear_pdo_assignments(slave_config_ref, sync_index) do
    Nif.slave_config_pdo_assign_clear(slave_config_ref, sync_index)
  end

  @doc """
  Adds a PDO to a sync manager's assignment list.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `sync_index` - Index of the sync manager
    * `pdo_index` - Index of the PDO to assign

  ## Examples

      iex> EthercatEx.Slave.add_pdo_assignment(slave_config, 0, 0x1600)
      :ok
  """
  @spec add_pdo_assignment(slave_config_ref(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, term()}
  def add_pdo_assignment(slave_config_ref, sync_index, pdo_index) do
    Nif.slave_config_pdo_assign_add(slave_config_ref, sync_index, pdo_index)
  end

  @doc """
  Clears all PDO entries for a specific PDO.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `pdo_index` - Index of the PDO

  ## Examples

      iex> EthercatEx.Slave.clear_pdo_mapping(slave_config, 0x1600)
      :ok
  """
  @spec clear_pdo_mapping(slave_config_ref(), non_neg_integer()) ::
          :ok | {:error, term()}
  def clear_pdo_mapping(slave_config_ref, pdo_index) do
    Nif.slave_config_pdo_mapping_clear(slave_config_ref, pdo_index)
  end

  @doc """
  Adds a PDO entry to a PDO's mapping.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `pdo_index` - Index of the PDO
    * `entry_index` - Index of the PDO entry
    * `entry_subindex` - Subindex of the PDO entry
    * `entry_bit_length` - Bit length of the entry

  ## Examples

      iex> EthercatEx.Slave.add_pdo_entry(slave_config, 0x1600, 0x7000, 0x01, 8)
      :ok
  """
  @spec add_pdo_entry(
          slave_config_ref(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok | {:error, term()}
  def add_pdo_entry(slave_config_ref, pdo_index, entry_index, entry_subindex, entry_bit_length) do
    Nif.slave_config_pdo_mapping_add(
      slave_config_ref,
      pdo_index,
      entry_index,
      entry_subindex,
      entry_bit_length
    )
  end

  @doc """
  Registers a PDO entry with a domain for process data exchange.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `entry_index` - Index of the PDO entry
    * `entry_subindex` - Subindex of the PDO entry
    * `domain_ref` - Reference to the domain

  Returns `{:ok, offset}` where offset is the byte offset in the domain.

  ## Examples

      iex> EthercatEx.Slave.register_pdo_entry(slave_config, 0x6000, 0x01, domain)
      {:ok, 0}
  """
  @spec register_pdo_entry(
          slave_config_ref(),
          non_neg_integer(),
          non_neg_integer(),
          reference()
        ) :: {:ok, non_neg_integer()} | {:error, term()}
  def register_pdo_entry(slave_config_ref, entry_index, entry_subindex, domain_ref) do
    Nif.slave_config_reg_pdo_entry(slave_config_ref, entry_index, entry_subindex, domain_ref)
  end

  @doc """
  Converts AL (Application Layer) state integer to atom.

  ## Examples

      iex> EthercatEx.Slave.al_state_to_atom(0x08)
      :op

      iex> EthercatEx.Slave.al_state_to_atom(0x02)
      :preop
  """
  @spec al_state_to_atom(non_neg_integer()) :: atom()
  def al_state_to_atom(@al_state_init), do: :init
  def al_state_to_atom(@al_state_preop), do: :preop
  def al_state_to_atom(@al_state_safeop), do: :safeop
  def al_state_to_atom(@al_state_op), do: :op
  def al_state_to_atom(_), do: :unknown

  @doc """
  Converts AL state atom to integer.

  ## Examples

      iex> EthercatEx.Slave.al_state_to_int(:op)
      0x08

      iex> EthercatEx.Slave.al_state_to_int(:preop)
      0x02
  """
  @spec al_state_to_int(atom()) :: non_neg_integer()
  def al_state_to_int(:init), do: @al_state_init
  def al_state_to_int(:preop), do: @al_state_preop
  def al_state_to_int(:safeop), do: @al_state_safeop
  def al_state_to_int(:op), do: @al_state_op
  def al_state_to_int(_), do: 0

  @doc """
  Gets the AL state name as a human-readable string.

  ## Examples

      iex> EthercatEx.Slave.al_state_name(:op)
      "Operational"

      iex> EthercatEx.Slave.al_state_name(:preop)
      "Pre-operational"
  """
  @spec al_state_name(atom()) :: String.t()
  def al_state_name(:init), do: "Init"
  def al_state_name(:preop), do: "Pre-operational"
  def al_state_name(:safeop), do: "Safe-operational"
  def al_state_name(:op), do: "Operational"
  def al_state_name(_), do: "Unknown"

  @doc """
  Normalizes slave information, converting raw data to a structured format.

  This function processes raw slave information from the NIF and converts
  it to a more usable format with proper types and atom conversion.

  ## Examples

      iex> raw_info = %{position: 1, vendor_id: 0x12345, al_state: 0x08}
      iex> EthercatEx.Slave.normalize_slave_info(raw_info)
      %{position: 1, vendor_id: 0x12345, al_state: :op, al_state_name: "Operational"}
  """
  @spec normalize_slave_info(map()) :: slave_info()
  def normalize_slave_info(raw_info) when is_map(raw_info) do
    al_state_int = Map.get(raw_info, :al_state, 0)
    al_state_atom = al_state_to_atom(al_state_int)

    raw_info
    |> Map.put(:al_state, al_state_atom)
    |> Map.put(:al_state_name, al_state_name(al_state_atom))
    |> Map.put(:error_flag, Map.get(raw_info, :error_flag, false))
  end

  @doc """
  Creates a default sync manager configuration for digital I/O slaves.

  ## Parameters

    * `input_pdo_index` - PDO index for inputs (e.g., 0x1A00)
    * `output_pdo_index` - PDO index for outputs (e.g., 0x1600)

  Returns a list of sync manager configurations.

  ## Examples

      iex> EthercatEx.Slave.default_io_sync_config(0x1A00, 0x1600)
      [
        %{index: 0, direction: :output, watchdog_mode: :default},
        %{index: 1, direction: :input, watchdog_mode: :default}
      ]
  """
  @spec default_io_sync_config(non_neg_integer(), non_neg_integer()) ::
          [sync_manager_config()]
  def default_io_sync_config(input_pdo_index, output_pdo_index) do
    [
      %{
        index: 0,
        direction: :output,
        watchdog_mode: :default,
        pdo_index: output_pdo_index
      },
      %{
        index: 1,
        direction: :input,
        watchdog_mode: :default,
        pdo_index: input_pdo_index
      }
    ]
  end

  @doc """
  Applies a complete slave configuration including sync managers and PDO mappings.

  This is a convenience function that configures sync managers and PDO mappings
  in the correct order for a typical I/O slave.

  ## Parameters

    * `slave_config_ref` - Reference to the slave configuration
    * `config` - Configuration map containing sync manager and PDO settings

  ## Examples

      config = %{
        sync_managers: [
          %{index: 0, direction: :output, watchdog_mode: :default},
          %{index: 1, direction: :input, watchdog_mode: :default}
        ],
        pdo_assignments: [
          %{sync_index: 0, pdo_index: 0x1600},
          %{sync_index: 1, pdo_index: 0x1A00}
        ],
        pdo_mappings: [
          %{pdo_index: 0x1600, entries: [%{index: 0x7000, subindex: 0x01, bits: 8}]},
          %{pdo_index: 0x1A00, entries: [%{index: 0x6000, subindex: 0x01, bits: 8}]}
        ]
      }

      EthercatEx.Slave.apply_configuration(slave_config, config)
  """
  @spec apply_configuration(slave_config_ref(), map()) :: :ok | {:error, term()}
  def apply_configuration(slave_config_ref, config) do
    with :ok <- configure_sync_managers(slave_config_ref, config),
         :ok <- configure_pdo_assignments(slave_config_ref, config),
         :ok <- configure_pdo_mappings(slave_config_ref, config) do
      :ok
    end
  end

  # Private helper functions

  defp configure_sync_managers(slave_config_ref, %{sync_managers: sync_managers}) do
    Enum.reduce_while(sync_managers, :ok, fn sm, :ok ->
      case configure_sync_manager(
             slave_config_ref,
             sm.index,
             sm.direction,
             sm.watchdog_mode
           ) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp configure_sync_managers(_slave_config_ref, _config), do: :ok

  defp configure_pdo_assignments(slave_config_ref, %{pdo_assignments: assignments}) do
    Enum.reduce_while(assignments, :ok, fn assignment, :ok ->
      with :ok <- clear_pdo_assignments(slave_config_ref, assignment.sync_index),
           :ok <-
             add_pdo_assignment(
               slave_config_ref,
               assignment.sync_index,
               assignment.pdo_index
             ) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp configure_pdo_assignments(_slave_config_ref, _config), do: :ok

  defp configure_pdo_mappings(slave_config_ref, %{pdo_mappings: mappings}) do
    Enum.reduce_while(mappings, :ok, fn mapping, :ok ->
      with :ok <- clear_pdo_mapping(slave_config_ref, mapping.pdo_index),
           :ok <- configure_pdo_entries(slave_config_ref, mapping) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp configure_pdo_mappings(_slave_config_ref, _config), do: :ok

  defp configure_pdo_entries(slave_config_ref, %{pdo_index: pdo_index, entries: entries}) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      case add_pdo_entry(
             slave_config_ref,
             pdo_index,
             entry.index,
             entry.subindex,
             entry.bits
           ) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
