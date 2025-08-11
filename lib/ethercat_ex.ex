defmodule EthercatEx do
  @moduledoc """
  EthercatEx is an Elixir wrapper for the EtherLab Master, enabling real-time EtherCAT communication.

  This module provides a high-level interface to configure and manage EtherCAT communication
  through a GenServer-based architecture that manages the master state and provides clean
  Elixir APIs for EtherCAT operations.
  """

  alias EthercatEx.{Master, Slave, Domain, Nif}

  ### Basic Configuration and Initialization ###

  @doc """
  Starts the EtherCAT master with the given configuration options.

  ## Options

    * `:name` - Name for the master GenServer (default: `:ethercat_master`)

  ## Examples

      iex> EthercatEx.start(name: :my_master)
      {:ok, #PID<0.123.0>}
  """
  def start(opts \\ []) do
    name = Keyword.get(opts, :name, :ethercat_master)
    Master.start_link(opts, name: name)
  end

  @impl true
  def init(_opts) do
    Nif.request_master()
  end

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
