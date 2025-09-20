defmodule EthercatEx do
  @moduledoc """
  EthercatEx is an Elixir wrapper for the EtherLab Master, enabling real-time EtherCAT communication.

  This module provides a high-level interface to configure and manage EtherCAT communication
  through a GenServer-based architecture that manages the master state and provides clean
  Elixir APIs for EtherCAT operations.

  There has to be two ways to configure an ethercat master.
  1. Dynamically when the master is connected to the slaves.
  2. Statically when before the master is connected to the slaves.

  1.
  - Get slave info
  - Save
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
    master = Nif.request_master(0)
    domain = Nif.master_create_domain(master)

    # output card
    slave_pos = 3
    sync_index = 0
    pdo_index = 0x1600
    entry_index = 0x7000
    entry_subindex = 0x01

    # input card
    alias = 0
    slave_pos = 0
    sync_index = 2
    pdo_index = 0x1A00
    entry_index = 0x6000
    entry_subindex = 0x00
    entry_bit_length = 1
    # EC_DIR_INPUT
    direction = 2
    # EC_WD_DEFAULT
    watchdog = 0

    sc = Nif.master_slave_config(master, alias, slave_pos, 0xFF11, 0xFF22)

    Nif.slave_config_sync_manager(sc, sync_index, direction, watchdog)

    Nif.slave_config_pdo_assign_clear(sc, sync_index)
    Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
    Nif.slave_config_pdo_mapping_clear(sc, pdo_index)
    Nif.slave_config_pdo_mapping_add(sc, pdo_index, entry_index, entry_subindex, entry_bit_length)

    offset =
      Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain)
      |> IO.inspect(label: "input: ")

    Nif.master_activate(master)
    Nif.cyclic_task(self(), master, [domain], [sc])
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
