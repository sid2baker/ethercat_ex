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

  @type master_state :: :init | :preop | :safeop | :op
  @type slave_info :: %{
          position: non_neg_integer(),
          vendor_id: non_neg_integer(),
          product_code: non_neg_integer(),
          revision_number: non_neg_integer(),
          serial_number: non_neg_integer(),
          al_state: master_state()
        }

  defstruct [
    :master_ref,
    :domains,
    :slave_configs,
    :cyclic_task_pid,
    :monitor_pid,
    :cycle_time_ms,
    state: :init,
    slaves: [],
    active: false
  ]

  @type t :: %__MODULE__{
          master_ref: reference() | nil,
          domains: map(),
          slave_configs: map(),
          cyclic_task_pid: pid() | nil,
          monitor_pid: pid() | nil,
          cycle_time_ms: pos_integer(),
          state: master_state(),
          slaves: [slave_info()],
          active: boolean()
        }

  ## Client API

  @doc """
  Starts the EtherCAT Master GenServer.

  ## Options

    * `:name` - Name for the GenServer (default: `__MODULE__`)
    * `:cycle_time_ms` - Cycle time in milliseconds (default: 1)
    * `:monitor_pid` - PID to send status updates to (optional)

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

  @doc """
  Requests an EtherCAT master from the EtherLab stack.

  This initializes the master resource through the NIF.
  """
  def request_master(server \\ __MODULE__) do
    GenServer.call(server, :request_master)
  end

  @doc """
  Creates a new domain for process data exchange.

  Returns `{:ok, domain_id}` on success.
  """
  def create_domain(server \\ __MODULE__) do
    GenServer.call(server, :create_domain)
  end

  @doc """
  Configures a slave at the specified position.

  ## Parameters

    * `alias` - Slave alias (usually 0)
    * `position` - Position on the bus
    * `vendor_id` - Vendor ID of the slave
    * `product_code` - Product code of the slave

  Returns `{:ok, slave_config_id}` on success.
  """
  def configure_slave(server \\ __MODULE__, alias, position, vendor_id, product_code) do
    GenServer.call(server, {:configure_slave, alias, position, vendor_id, product_code})
  end

  @doc """
  Registers a PDO entry for a slave configuration.

  ## Parameters

    * `slave_config_id` - ID of the slave configuration
    * `entry_index` - PDO entry index
    * `entry_subindex` - PDO entry subindex
    * `domain_id` - ID of the domain to register with

  Returns `{:ok, offset}` where offset is the byte offset in the domain.
  """
  def register_pdo_entry(
        server \\ __MODULE__,
        slave_config_id,
        entry_index,
        entry_subindex,
        domain_id
      ) do
    GenServer.call(
      server,
      {:register_pdo_entry, slave_config_id, entry_index, entry_subindex, domain_id}
    )
  end

  @doc """
  Activates the master, transitioning all slaves to operational state.

  This must be called after all configuration is complete.
  """
  def activate(server \\ __MODULE__) do
    GenServer.call(server, :activate)
  end

  @doc """
  Starts the cyclic task for real-time communication.

  The cyclic task handles the periodic exchange of process data.
  """
  def start_cyclic_task(server \\ __MODULE__) do
    GenServer.call(server, :start_cyclic_task)
  end

  @doc """
  Stops the cyclic task.
  """
  def stop_cyclic_task(server \\ __MODULE__) do
    GenServer.call(server, :stop_cyclic_task)
  end

  @doc """
  Gets the current master state.

  Returns a map with master status information including:
  - `:slaves_responding` - Number of slaves responding
  - `:al_states` - Application layer states
  - `:link_up` - Link status
  """
  def get_master_state(server \\ __MODULE__) do
    GenServer.call(server, :get_master_state)
  end

  @doc """
  Gets information about a specific slave.

  ## Parameters

    * `slave_position` - Position of the slave on the bus

  Returns `{:ok, slave_info}` or `{:error, reason}`.
  """
  def get_slave_info(server \\ __MODULE__, slave_position) do
    GenServer.call(server, {:get_slave_info, slave_position})
  end

  @doc """
  Scans the bus and returns information about all detected slaves.
  """
  def scan_slaves(server \\ __MODULE__) do
    GenServer.call(server, :scan_slaves)
  end

  @doc """
  Reads a value from a domain at the specified offset.

  ## Parameters

    * `domain_id` - ID of the domain
    * `offset` - Byte offset in the domain

  Returns the byte value at the offset.
  """
  def read_domain_value(server \\ __MODULE__, domain_id, offset) do
    GenServer.call(server, {:read_domain_value, domain_id, offset})
  end

  @doc """
  Resets the master and all slaves.
  """
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @doc """
  Releases the master resource and stops the GenServer.
  """
  def release(server \\ __MODULE__) do
    GenServer.call(server, :release)
  end

  @doc """
  Gets the current state of the GenServer.
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    cycle_time_ms = Keyword.get(opts, :cycle_time_ms, 1)
    monitor_pid = Keyword.get(opts, :monitor_pid)

    state = %__MODULE__{
      master_ref: nil,
      domains: %{},
      slave_configs: %{},
      cyclic_task_pid: nil,
      monitor_pid: monitor_pid,
      cycle_time_ms: cycle_time_ms,
      state: :init,
      slaves: [],
      active: false
    }

    Logger.info("EtherCAT Master GenServer started")
    {:ok, state}
  end

  @impl true
  def handle_call(:request_master, _from, state) do
    case Nif.request_master() do
      {:ok, master_ref} ->
        new_state = %{state | master_ref: master_ref, state: :preop}
        Logger.info("EtherCAT master requested successfully")
        {:reply, {:ok, master_ref}, new_state}

      {:error, reason} ->
        Logger.error("Failed to request EtherCAT master: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:create_domain, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:create_domain, _from, %{master_ref: master_ref, domains: domains} = state) do
    case Nif.master_create_domain(master_ref) do
      {:ok, domain_ref} ->
        domain_id = map_size(domains)
        new_domains = Map.put(domains, domain_id, domain_ref)
        new_state = %{state | domains: new_domains}
        Logger.debug("Created domain with ID: #{domain_id}")
        {:reply, {:ok, domain_id}, new_state}

      {:error, reason} ->
        Logger.error("Failed to create domain: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(
        {:configure_slave, alias, position, vendor_id, product_code},
        _from,
        %{master_ref: nil} = state
      ) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(
        {:configure_slave, alias, position, vendor_id, product_code},
        _from,
        %{master_ref: master_ref, slave_configs: configs} = state
      ) do
    case Nif.master_slave_config(master_ref, alias, position, vendor_id, product_code) do
      {:ok, slave_config_ref} ->
        config_id = map_size(configs)

        new_configs =
          Map.put(configs, config_id, %{
            ref: slave_config_ref,
            alias: alias,
            position: position,
            vendor_id: vendor_id,
            product_code: product_code
          })

        new_state = %{state | slave_configs: new_configs}
        Logger.debug("Configured slave at position #{position} with ID: #{config_id}")
        {:reply, {:ok, config_id}, new_state}

      {:error, reason} ->
        Logger.error("Failed to configure slave: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(
        {:register_pdo_entry, slave_config_id, entry_index, entry_subindex, domain_id},
        _from,
        %{slave_configs: configs, domains: domains} = state
      ) do
    with {:ok, slave_config} <- Map.fetch(configs, slave_config_id),
         {:ok, domain_ref} <- Map.fetch(domains, domain_id) do
      case Nif.slave_config_reg_pdo_entry(
             slave_config.ref,
             entry_index,
             entry_subindex,
             domain_ref
           ) do
        {:ok, offset} ->
          Logger.debug(
            "Registered PDO entry #{entry_index}:#{entry_subindex} at offset #{offset}"
          )

          {:reply, {:ok, offset}, state}

        {:error, reason} ->
          Logger.error("Failed to register PDO entry: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      :error ->
        {:reply, {:error, :invalid_id}, state}
    end
  end

  @impl true
  def handle_call(:activate, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:activate, _from, %{master_ref: master_ref} = state) do
    case Nif.master_activate(master_ref) do
      :ok ->
        new_state = %{state | active: true, state: :op}
        Logger.info("EtherCAT master activated successfully")
        send_status_update(state, :activated)
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to activate master: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:start_cyclic_task, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:start_cyclic_task, _from, %{cyclic_task_pid: pid} = state) when is_pid(pid) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call(:start_cyclic_task, _from, %{master_ref: master_ref, domains: domains} = state)
      when map_size(domains) > 0 do
    # Use the first domain for the cyclic task
    {_domain_id, domain_ref} = Enum.at(domains, 0)

    parent_pid = self()

    task_pid =
      spawn_link(fn ->
        cyclic_task_loop(parent_pid, master_ref, domain_ref, state.cycle_time_ms)
      end)

    new_state = %{state | cyclic_task_pid: task_pid}
    Logger.info("Cyclic task started with PID: #{inspect(task_pid)}")
    send_status_update(state, :cyclic_task_started)
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
    send_status_update(state, :cyclic_task_stopped)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_master_state, _from, %{master_ref: nil} = state) do
    {:reply, {:error, :no_master}, state}
  end

  def handle_call(:get_master_state, _from, %{master_ref: master_ref} = state) do
    case Nif.master_state(master_ref) do
      {:ok, master_state} ->
        {:reply, {:ok, master_state}, state}

      {:error, reason} ->
        Logger.error("Failed to get master state: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
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
    case Nif.master_state(master_ref) do
      {:ok, %{slaves_responding: num_slaves}} ->
        slaves =
          Enum.map(0..(num_slaves - 1), fn position ->
            case Nif.master_get_slave(master_ref, position) do
              {:ok, slave_info} ->
                Map.put(slave_info, :position, position)

              {:error, _} ->
                %{position: position, error: :unavailable}
            end
          end)

        new_state = %{state | slaves: slaves}
        Logger.info("Scanned #{num_slaves} slaves")
        {:reply, {:ok, slaves}, new_state}

      {:error, reason} ->
        Logger.error("Failed to scan slaves: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
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
    case Nif.master_reset(master_ref) do
      :ok ->
        new_state = %{state | state: :init, active: false}
        Logger.info("EtherCAT master reset successfully")
        send_status_update(state, :reset)
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to reset master: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:release, _from, %{master_ref: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:release, _from, %{master_ref: master_ref, cyclic_task_pid: task_pid} = state) do
    # Stop cyclic task if running
    if task_pid do
      Process.exit(task_pid, :normal)
    end

    case Nif.release_master(master_ref) do
      :ok ->
        Logger.info("EtherCAT master released successfully")
        send_status_update(state, :released)
        {:stop, :normal, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to release master: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{cyclic_task_pid: pid} = state) do
    Logger.warning("Cyclic task exited with reason: #{inspect(reason)}")
    new_state = %{state | cyclic_task_pid: nil}
    send_status_update(state, {:cyclic_task_exited, reason})
    {:noreply, new_state}
  end

  def handle_info(:unblock, state) do
    # Message from cyclic task - just acknowledge
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{master_ref: master_ref, cyclic_task_pid: task_pid}) do
    Logger.info("EtherCAT Master terminating with reason: #{inspect(reason)}")

    # Stop cyclic task if running
    if task_pid do
      Process.exit(task_pid, :kill)
    end

    # Release master resource if we have one
    if master_ref do
      case Nif.release_master(master_ref) do
        :ok ->
          Logger.info("Master resource released on termination")

        {:error, reason} ->
          Logger.error("Failed to release master on termination: #{inspect(reason)}")
      end
    end

    :ok
  end

  ## Private Functions

  defp cyclic_task_loop(parent_pid, master_ref, domain_ref, cycle_time_ms) do
    try do
      # Send process data
      :ok = Nif.master_receive(master_ref)
      :ok = Nif.domain_process(domain_ref)

      # Application code would process domain data here

      # Queue and send process data
      :ok = Nif.domain_queue(domain_ref)
      :ok = Nif.master_send(master_ref)

      # Wait for next cycle
      Process.sleep(cycle_time_ms)

      # Continue loop
      cyclic_task_loop(parent_pid, master_ref, domain_ref, cycle_time_ms)
    rescue
      e ->
        Logger.error("Error in cyclic task: #{inspect(e)}")
        send(parent_pid, {:cyclic_task_error, e})
    end
  end

  defp send_status_update(%{monitor_pid: nil}, _event), do: :ok

  defp send_status_update(%{monitor_pid: pid}, event) when is_pid(pid) do
    send(pid, {:ethercat_master, event})
  end
end
