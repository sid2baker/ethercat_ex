defmodule EthercatEx do
  @moduledoc """
  EthercatEx is an Elixir wrapper for the EtherLab Master, enabling real-time EtherCAT communication.

  This module provides a high-level interface to configure and manage EtherCAT communication.
  """

  ### Basic Configuration and Initialization ###

  @doc """
  Initializes the EtherCAT master with the given configuration options.

  ## Options

    * `:interface` - (Required) Network interface to use for EtherCAT communication (e.g., `"eth0"`).
    * `:dc` - (Optional) Enable distributed clocks (default: `false`).
    * `:timeout` - (Optional) Timeout for operations in milliseconds (default: `1000`).

  ## Examples

      iex> EthercatEx.init(interface: "eth0", dc: true, timeout: 2000)
      :ok
  """
  def init(opts \\ []) do
    # NIF or Port communication to initialize EtherLab Master
  end

  @doc """
  Shuts down the EtherCAT master.

  ## Examples

      iex> EthercatEx.shutdown()
      :ok
  """
  def shutdown() do
    # Cleanly stop EtherCAT operations
  end

  ### Slave Management ###

  @doc """
  Scans the EtherCAT bus for connected slaves and returns a list of detected slaves.

  ## Examples

      iex> EthercatEx.scan()
      [
        %{id: 1, vendor_id: 0x12345678, product_code: 0x87654321},
        %{id: 2, vendor_id: 0x23456789, product_code: 0x98765432}
      ]
  """
  def scan() do
    # Interact with EtherLab to retrieve slave details
  end

  @doc """
  Configures a slave with the specified parameters.

  ## Parameters

    * `slave_id` - The ID of the slave to configure.
    * `config` - A map containing configuration details (e.g., PDO mappings, sync managers).

  ## Examples

      iex> EthercatEx.configure_slave(1, %{pdo_mapping: ...})
      :ok
  """
  def configure_slave(slave_id, config) do
    # Apply configuration to the specified slave
  end

  ### Data Exchange ###

  @doc """
  Reads process data from a specified slave.

  ## Parameters

    * `slave_id` - The ID of the slave to read from.

  ## Examples

      iex> EthercatEx.read_pdo(1)
      %{inputs: [0x12, 0x34], outputs: [0x56, 0x78]}
  """
  def read_pdo(slave_id) do
    # Use EtherLab to read process data
  end

  @doc """
  Writes process data to a specified slave.

  ## Parameters

    * `slave_id` - The ID of the slave to write to.
    * `data` - The data to write (e.g., outputs).

  ## Examples

      iex> EthercatEx.write_pdo(1, %{outputs: [0xAA, 0xBB]})
      :ok
  """
  def write_pdo(slave_id, data) do
    # Use EtherLab to write process data
  end

  ### Status and Diagnostics ###

  @doc """
  Gets the status of the EtherCAT master.

  ## Examples

      iex> EthercatEx.status()
      %{state: :operational, slaves: [%{id: 1, state: :operational}, %{id: 2, state: :pre_operational}]}
  """
  def status() do
    # Retrieve the master and slave statuses
  end

  @doc """
  Resets a slave to a known state.

  ## Parameters

    * `slave_id` - The ID of the slave to reset.

  ## Examples

      iex> EthercatEx.reset_slave(1)
      :ok
  """
  def reset_slave(slave_id) do
    # Reset the specified slave
  end

  ### Advanced ###

  @doc """
  Sends a custom SDO (Service Data Object) request to a slave.

  ## Parameters

    * `slave_id` - The ID of the slave to send the request to.
    * `index` - The object index.
    * `subindex` - The object subindex.
    * `data` - The data to send (optional, for writes).

  ## Examples

      iex> EthercatEx.sdo_request(1, 0x6000, 0x01)
      {:ok, 0x1234}

      iex> EthercatEx.sdo_request(1, 0x6000, 0x01, 0x5678)
      :ok
  """
  def sdo_request(slave_id, index, subindex, data \\ nil) do
    # Handle SDO request (read/write)
  end

  ### Utilities ###

  @doc """
  Attaches a monitor to track events or errors from the EtherCAT master.

  ## Parameters

    * `pid` - The process to send notifications to.

  ## Examples

      iex> EthercatEx.attach_monitor(self())
      :ok
  """
  def attach_monitor(pid) do
    # Allow monitoring of EtherCAT events
  end

  # TODO just for testing
  alias EthercatEx.Nif

  def master() do
    Nif.request_master()
  end

  def domain(master) do
    Nif.master_create_domain(master)
  end

  def test do
    master = Nif.request_master()
    domain = Nif.master_create_domain(master)


    # input card
    slave_pos = 1
    sync_index = 0
    pdo_index = 0x1a00
    entry_index = 0x6000
    entry_subindex = 0x01
    slave = Nif.master_get_slave(master, slave_pos)
    sc = Nif.master_slave_config(master, sync_index, slave_pos, slave.vendor_id, slave.product_code)
    #Nif.slave_config_sync_manager(sc, sync_index, 2, 1) # EC_DIR_INPUT = 2
    #Nif.slave_config_pdo_assign_clear(sc, sync_index)
    #Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    #Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    #Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, 1)

    offset = Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
    |> IO.inspect(label: "input: ")
    offset = Nif.slave_config_reg_pdo_entry(sc, 0x6010, entry_subindex, domain)
    |> IO.inspect(label: "input: ")
    offset = Nif.slave_config_reg_pdo_entry(sc, 0x6020, entry_subindex, domain)
    |> IO.inspect(label: "input: ")
    offset = Nif.slave_config_reg_pdo_entry(sc, 0x6030, entry_subindex, domain)
    |> IO.inspect(label: "input: ")
    offset = Nif.slave_config_reg_pdo_entry(sc, 0x6080, entry_subindex, domain)
    |> IO.inspect(label: "input: ")

    # output card
    slave_pos = 2
    sync_index = 0
    pdo_index = 0x1600
    entry_index = 0x7000
    entry_subindex = 0x01
    slave = Nif.master_get_slave(master, slave_pos)
    sc = Nif.master_slave_config(master, sync_index, slave_pos, slave.vendor_id, slave.product_code)

    offset = Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
    |> IO.inspect(label: "output: ")

    Nif.master_activate(master)
    {master, domain}
  end

  def cyclic(master, domain) do
    Nif.master_receive(master)
    Nif.domain_process(domain)
    Nif.get_domain_value(domain, 0)
    |> IO.inspect(label: "Value 0")
    Nif.get_domain_value(domain, 1)
    |> IO.inspect(label: "Value 1")
    Nif.domain_queue(domain)
    Nif.master_send(master)
  end


  @doc """
      al_state:
      EC_AL_STATE_INIT = 1,
      EC_AL_STATE_PREOP = 2,
      EC_AL_STATE_SAFEOP = 4,
      EC_AL_STATE_OP = 8,
  """
  def slaves(master) do
    %{slaves_responding: num_slaves} = Nif.master_state(master)

    Enum.map(0..num_slaves-1, fn slave ->
      Nif.master_get_slave(master, slave)
    end)
  end
end
