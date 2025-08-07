defmodule EthercatEx do
  @moduledoc """
  EthercatEx is an Elixir wrapper for the EtherLab Master, enabling real-time EtherCAT communication.

  This module provides a high-level interface to configure and manage EtherCAT communication
  through a GenServer-based architecture that manages the master state and provides clean
  Elixir APIs for EtherCAT operations.
  """

  alias EthercatEx.{Master, Slave, Domain}

  ### Basic Configuration and Initialization ###

  @doc """
  Starts the EtherCAT master with the given configuration options.

  ## Options

    * `:name` - Name for the master GenServer (default: `:ethercat_master`)
    * `:cycle_time_ms` - Cycle time in milliseconds (default: `1`)
    * `:monitor_pid` - Process to send status updates to (optional)

  ## Examples

      iex> EthercatEx.start(name: :my_master, cycle_time_ms: 10)
      {:ok, #PID<0.123.0>}
  """
  def start(opts \\ []) do
    name = Keyword.get(opts, :name, :ethercat_master)
    Master.start_link(opts)
  end

  @doc """
  Initializes the EtherCAT master by requesting it from EtherLab.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.init()
      {:ok, master_ref}
  """
  def init(master \\ :ethercat_master) do
    Master.request_master(master)
  end

  @doc """
  Shuts down the EtherCAT master and releases all resources.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.shutdown()
      :ok
  """
  def shutdown(master \\ :ethercat_master) do
    Master.release(master)
  end

  ### Slave Management ###

  @doc """
  Scans the EtherCAT bus for connected slaves and returns a list of detected slaves.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.scan()
      {:ok, [
        %{position: 1, vendor_id: 0x12345678, product_code: 0x87654321},
        %{position: 2, vendor_id: 0x23456789, product_code: 0x98765432}
      ]}
  """
  def scan(master \\ :ethercat_master) do
    Master.scan_slaves(master)
  end

  @doc """
  Configures a slave at the specified position.

  ## Parameters

    * `position` - Position of the slave on the bus
    * `vendor_id` - Vendor ID of the slave
    * `product_code` - Product code of the slave
    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.configure_slave(1, 0x12345678, 0x87654321)
      {:ok, slave_config_id}
  """
  def configure_slave(position, vendor_id, product_code, master \\ :ethercat_master) do
    Master.configure_slave(master, 0, position, vendor_id, product_code)
  end

  @doc """
  Creates a domain for process data exchange.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.create_domain()
      {:ok, domain_id}
  """
  def create_domain(master \\ :ethercat_master) do
    Master.create_domain(master)
  end

  ### Data Exchange ###

  @doc """
  Reads process data from the domain at the specified offset.

  ## Parameters

    * `domain_id` - ID of the domain
    * `offset` - Byte offset in the domain
    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.read_domain_value(0, 0)
      {:ok, 255}
  """
  def read_domain_value(domain_id, offset, master \\ :ethercat_master) do
    Master.read_domain_value(master, domain_id, offset)
  end

  ### Status and Diagnostics ###

  @doc """
  Gets the status of the EtherCAT master.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.status()
      {:ok, %{slaves_responding: 2, al_states: 8, link_up: 1}}
  """
  def status(master \\ :ethercat_master) do
    Master.get_master_state(master)
  end

  @doc """
  Gets information about a specific slave.

  ## Parameters

    * `position` - Position of the slave on the bus
    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.get_slave_info(1)
      {:ok, %{position: 1, vendor_id: 0x12345, al_state: :op}}
  """
  def get_slave_info(position, master \\ :ethercat_master) do
    Master.get_slave_info(master, position)
  end

  @doc """
  Resets the EtherCAT master and all slaves.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.reset()
      :ok
  """
  def reset(master \\ :ethercat_master) do
    Master.reset(master)
  end

  @doc """
  Activates the master, transitioning all slaves to operational state.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.activate()
      :ok
  """
  def activate(master \\ :ethercat_master) do
    Master.activate(master)
  end

  @doc """
  Starts the cyclic task for real-time communication.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.start_cyclic()
      {:ok, #PID<0.125.0>}
  """
  def start_cyclic(master \\ :ethercat_master) do
    Master.start_cyclic_task(master)
  end

  @doc """
  Stops the cyclic task.

  ## Parameters

    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.stop_cyclic()
      :ok
  """
  def stop_cyclic(master \\ :ethercat_master) do
    Master.stop_cyclic_task(master)
  end

  ### Advanced ###

  @doc """
  Registers a PDO entry for a slave configuration.

  ## Parameters

    * `slave_config_id` - ID of the slave configuration
    * `entry_index` - PDO entry index
    * `entry_subindex` - PDO entry subindex
    * `domain_id` - ID of the domain
    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.register_pdo_entry(0, 0x6000, 0x01, 0)
      {:ok, offset}
  """
  def register_pdo_entry(
        slave_config_id,
        entry_index,
        entry_subindex,
        domain_id,
        master \\ :ethercat_master
      ) do
    Master.register_pdo_entry(master, slave_config_id, entry_index, entry_subindex, domain_id)
  end

  ### Utilities ###

  @doc """
  Attaches a monitor to track events or errors from the EtherCAT master.

  ## Parameters

    * `pid` - The process to send notifications to.
    * `master` - Name of the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.attach_monitor(self())
      :ok
  """
  def attach_monitor(pid, master \\ :ethercat_master) do
    # This would require extending the Master GenServer to support runtime monitor attachment
    # For now, the monitor_pid should be set when starting the master
    {:error, :not_implemented}
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
    slave_pos = 2
    sync_index = 0
    pdo_index = 0x1A00
    entry_index = 0x6000
    entry_subindex = 0x01
    slave = Nif.master_get_slave(master, slave_pos)

    sc =
      Nif.master_slave_config(master, sync_index, slave_pos, slave.vendor_id, slave.product_code)

    # Nif.slave_config_sync_manager(sc, sync_index, 2, 1) # EC_DIR_INPUT = 2
    # Nif.slave_config_pdo_assign_clear(sc, sync_index)
    # Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    # Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    # Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, 1)

    offset =
      Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    offset =
      Nif.slave_config_reg_pdo_entry(sc, 0x6010, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    offset =
      Nif.slave_config_reg_pdo_entry(sc, 0x6020, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    offset =
      Nif.slave_config_reg_pdo_entry(sc, 0x6030, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    offset =
      Nif.slave_config_reg_pdo_entry(sc, 0x6080, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    # output card
    slave_pos = 3
    sync_index = 0
    pdo_index = 0x1600
    entry_index = 0x7000
    entry_subindex = 0x01
    slave = Nif.master_get_slave(master, slave_pos)

    sc =
      Nif.master_slave_config(master, sync_index, slave_pos, slave.vendor_id, slave.product_code)

    offset =
      Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
      |> IO.inspect(label: "output: ")

    Nif.master_activate(master)
    spawn(master, [domain], [sc])
    {master, domain, sc}
  end

  def start_cyclic(master, domains, slaves) do
    this = self()
    threaded = spawn(fn -> Nif.cyclic_task(this, master, domains, slaves) end)
  end

  def cyclic(master, domain) do
    Nif.domain_queue(domain)
    Nif.master_send(master)
    Nif.master_receive(master)
    Nif.domain_process(domain)

    Nif.get_domain_value(domain, 0)
    |> IO.inspect(label: "Value 0")

    Nif.get_domain_value(domain, 1)
    |> IO.inspect(label: "Value 1")
  end

  @doc """
      al_state:
      EC_AL_STATE_INIT = 1,
      EC_AL_STATE_PREOP = 2,
      EC_AL_STATE_SAFEOP = 4,
      EC_AL_STATE_OP = 8,
  """
  def slaves(master) do
    %{slaves_responding: num_slaves} = Nif.get_master_state(master)

    Enum.map(0..(num_slaves - 1), fn slave ->
      Nif.master_get_slave(master, slave)
    end)
  end
end
