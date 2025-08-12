defmodule EthercatEx.Master do
  @moduledoc """
  GenServer for managing EtherCAT master operations.

  This module provides a high-level interface to the EtherLab Master through
  the Zigler NIF bridge. It manages the master resource, domains, slave
  configurations, and provides a clean Elixir API for EtherCAT operations.
  """

  use GenServer
  require Logger

  alias EthercatEx.{Nif, Domain, Slave}

  defstruct [
    :master_ref,
    :domains,
    :slaves,
    :cyclic_task_pid,
    active: false
  ]

  @type t :: %__MODULE__{
          master_ref: reference() | nil,
          domains: [pid()],
          slaves: [pid()],
          cyclic_task_pid: pid() | nil,
          active: boolean()
        }

  @type master_state :: :init | :preop | :safeop | :op

  ## Client API

  @doc """
  Starts the EtherCAT Master GenServer.

  ## Options

    * `:name` - Name for the GenServer (default: `__MODULE__`)

  ## Examples

      iex> EthercatEx.Master.start_link()
      {:ok, #PID<0.123.0>}

      iex> EthercatEx.Master.start_link(name: :ethercat_master, cycle_time_ms: 10)
      {:ok, #PID<0.124.0>}
  """
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_slave_config(server, slave_config) do
    GenServer.call(server, {:add_slave_config, slave_config})
  end

  @doc """
  Activates the master, transitioning all slaves to operational state.

  This must be called after all configuration is complete.
  """
  def activate(server) do
    GenServer.call(server, :activate)
  end

  @doc """
  Starts the cyclic task for real-time communication.

  The cyclic task handles the periodic exchange of process data.
  """
  def start_cyclic_task(server) do
    GenServer.call(server, :start_cyclic_task)
  end

  @doc """
  Stops the cyclic task.
  """
  def stop_cyclic_task(server) do
    GenServer.call(server, :stop_cyclic_task)
  end

  @doc """
  Gets the current master state.

  Returns a map with master status information including:
  - `:slaves_responding` - Number of slaves responding
  - `:al_states` - Application layer states
  - `:link_up` - Link status
  """
  def get_master_state(server) do
    GenServer.call(server, :get_master_state)
  end

  @doc """
  Gets information about a specific slave.

  ## Parameters

    * `slave_position` - Position of the slave on the bus

  Returns `{:ok, slave_info}` or `{:error, reason}`.
  """
  def get_slave_info(server, slave_position) do
    GenServer.call(server, {:get_slave_info, slave_position})
  end

  @doc """
  Scans the bus and returns information about all detected slaves.
  """
  def scan_slaves(server) do
    GenServer.call(server, :scan_slaves)
  end

  @doc """
  Reads a value from a domain at the specified offset.

  ## Parameters

    * `domain_id` - ID of the domain
    * `offset` - Byte offset in the domain

  Returns the byte value at the offset.
  """
  def read_domain_value(server, domain_id, offset) do
    GenServer.call(server, {:read_domain_value, domain_id, offset})
  end

  @doc """
  Resets the master and all slaves.
  """
  def reset(server) do
    GenServer.call(server, :reset)
  end

  @doc """
  Releases the master resource and stops the GenServer.
  """
  def release(server) do
    GenServer.call(server, :release)
  end

  @doc """
  Gets the current state of the GenServer.
  """
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    master = Nif.request_master()

    state = %__MODULE__{
      master_ref: master,
      domains: [],
      slaves: [],
      cyclic_task_pid: nil,
      active: false
    }

    Logger.info("EtherCAT Master GenServer started")

    {:ok, state}
  end

  @impl true
  def handle_call(:request_master, _from, state) do
    master_ref = Nif.request_master()
    new_state = %{state | master_ref: master_ref}
    Logger.info("EtherCAT master requested successfully")
    {:reply, {:ok, master_ref}, new_state}
  end

  @impl true
  def handle_call({:add_slave_config, slave_config}, _from, state) do
    sc =
      Nif.master_slave_config(
        state.master_ref,
        slave_config.alias,
        slave_config.position,
        slave_config.vendor_id,
        slave_config.product_code
      )

    # TODO find a better solution to get current domains
    domains =
      for {sync_index, sync_manager} <- slave_config.sync_managers do
        direction =
          case sync_manager.direction do
            :output -> 1
            :input -> 2
            :count -> 3
            _ -> 0
          end

        watchdog_mode =
          case sync_manager.watchdog_mode do
            :enable -> 1
            :disable -> 2
            _ -> 0
          end

        Nif.slave_config_sync_manager(sc, sync_index, direction, watchdog_mode)
        Nif.slave_config_pdo_assign_clear(sc, sync_index)

        for {pdo_index, data_objects} <- sync_manager.pdos do
          Nif.slave_config_pdo_assign_add(sc, sync_index, pdo_index)
          Nif.slave_config_pdo_mapping_clear(sc, pdo_index)

          for %{
                entry: {entry_index, entry_subindex, entry_size},
                domain: domain_name,
                name: entry_name
              } <-
                data_objects do
            {domain_ref, domain_pid, domains} =
              case Domain.start_link(domain_name) do
                {:ok, pid} ->
                  domain_ref = Nif.master_create_domain(state.master_ref)
                  :ok = Domain.set_ref(pid, domain_ref)
                  {domain_ref, pid, [pid | state.domains]}

                {:error, {:already_started, pid}} ->
                  {Domain.get_ref(pid), pid, state.domains}
              end

            Nif.slave_config_pdo_mapping_add(
              sc,
              pdo_index,
              entry_index,
              entry_subindex,
              entry_size
            )

            offset = Nif.slave_config_reg_pdo_entry(sc, entry_index, entry_subindex, domain_ref)
            # TODO get bitsize offset and add it to offset
            Domain.add_offset(domain_pid, entry_name, offset * 8, entry_size)

            domains
          end
        end
      end
      |> List.flatten()
      |> Enum.uniq()

    # if everything is ok, start the slave
    # TODO fix sc slave_config naming issue. sc is the ref
    {:ok, slave} = Slave.start_link(sc, slave_config)

    {:reply, {:ok, sc}, %{state | domains: domains, slaves: [slave | state.slaves]}}
  end

  @impl true
  def handle_call(
        {:register_pdo_entry, slave_config_id, entry_index, entry_subindex, domain_id},
        _from,
        %{slave_configs: configs, domains: domains} = state
      ) do
    with {:ok, slave_config_ref} <- Map.fetch(configs, slave_config_id),
         {:ok, domain_ref} <- Map.fetch(domains, domain_id) do
      offset =
        Nif.ecrt_slave_config_reg_pdo_entry(
          slave_config_ref,
          entry_index,
          entry_subindex,
          domain_ref,
          0
        )

      Logger.debug(
        "Registered PDO entry: index=0x#{Integer.to_string(entry_index, 16)}, subindex=0x#{Integer.to_string(entry_subindex, 16)}, offset=#{offset}"
      )

      {:reply, {:ok, offset}, state}
    else
      :error -> {:reply, {:error, :invalid_config_or_domain}, state}
    end
  end

  @impl true
  def handle_call(:activate, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:activate, _from, %{master_ref: master_ref} = state) do
    :ok = Nif.master_activate(master_ref)
    new_state = %{state | active: true}
    Logger.info("EtherCAT master activated successfully")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:start_cyclic_task, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:start_cyclic_task, _from, %{cyclic_task_pid: pid} = state) when is_pid(pid) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call(
        :start_cyclic_task,
        _from,
        %{master_ref: master_ref, domains: domains, slaves: slaves} = state
      ) do
    parent_pid = self()

    domain_configs =
      Enum.map(domains, fn pid ->
        %{
          pid: pid,
          resource: Domain.get_ref(pid),
          interval: 0
        }
        |> IO.inspect()
      end)

    slave_configs =
      Enum.map(slaves, fn pid ->
        %{
          pid: pid,
          resource: Slave.get_config_ref(pid)
        }
        |> IO.inspect()
      end)

    task_pid =
      spawn_link(fn ->
        Nif.cyclic_task(parent_pid, master_ref, domain_configs, slave_configs)
      end)

    new_state = %{state | cyclic_task_pid: task_pid}
    Logger.info("Cyclic task started with PID: #{inspect(task_pid)}")
    {:reply, {:ok, task_pid}, new_state}
  end

  def handle_call(:start_cyclic_task, _from, state) do
    {:reply, {:error, :no_domains}, state}
  end

  @impl true
  def handle_call(:stop_cyclic_task, _from, %{cyclic_task_pid: nil} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call(:stop_cyclic_task, _from, %{cyclic_task_pid: pid} = state) do
    Process.exit(pid, :normal)
    new_state = %{state | cyclic_task_pid: nil}
    Logger.info("Cyclic task stopped")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_master_state, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:get_master_state, _from, %{master_ref: master_ref} = state) do
    # Note: master_state function needs to be implemented in NIF
    master_state = :unknown
    Logger.debug("Master state: #{inspect(master_state)}")
    {:reply, {:ok, master_state}, state}
  end

  @impl true
  def handle_call({:get_slave_info, slave_position}, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call({:get_slave_info, slave_position}, _from, %{master_ref: master_ref} = state) do
    case Nif.master_get_slave(master_ref, slave_position) do
      {:ok, slave_info} ->
        {:reply, {:ok, slave_info}, state}

      {:error, reason} ->
        Logger.error(
          "Failed to get slave info for position #{slave_position}: #{inspect(reason)}"
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:scan_slaves, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:scan_slaves, _from, %{master_ref: master_ref} = state) do
    # Scan for available slaves by trying positions 0-15 (typical range)
    slaves =
      Enum.reduce(0..15, [], fn position, acc ->
        case Nif.master_get_slave(master_ref, position) do
          {:ok, slave_info} ->
            [Map.put(slave_info, :position, position) | acc]

          {:error, _} ->
            acc
        end
      end)
      |> Enum.reverse()

    Logger.info("Scanned #{length(slaves)} slaves")
    {:reply, {:ok, slaves}, state}
  end

  @impl true
  def handle_call({:read_domain_value, domain_id, offset}, _from, %{domains: domains} = state) do
    case Map.fetch(domains, domain_id) do
      {:ok, domain_ref} ->
        value = Nif.get_domain_value(domain_ref, offset)
        {:reply, {:ok, value}, state}

      :error ->
        {:reply, {:error, :invalid_domain_id}, state}
    end
  end

  @impl true
  def handle_call(:reset, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:reset, _from, %{master_ref: master_ref} = state) do
    :ok = Nif.master_reset(master_ref)
    new_state = %{state | active: false}
    Logger.info("EtherCAT master reset successfully")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:release, _from, %{master_ref: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:release, _from, %{master_ref: master_ref, cyclic_task_pid: task_pid} = state) do
    # Stop cyclic task if running
    if task_pid do
      Process.exit(task_pid, :shutdown)
    end

    :ok = Nif.master_release(master_ref)
    Logger.info("EtherCAT master released successfully")
    {:reply, :ok, %{state | master_ref: nil, cyclic_task_pid: nil, active: false}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:data_changed, data}, state) do
    state.module.parse(data)
    {:noreply, state}
  end

  def handle_info(:unblock, state) do
    # Message from cyclic task - just acknowledge
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end
end
