defmodule EthercatEx.Cli do
  @moduledoc """
  A comprehensive Elixir wrapper for the EtherLab EtherCAT CLI, executing all commands within a GenServer.

  This module uses MuonTrap to execute `ethercat` commands, supporting all available commands for controlling
  and monitoring EtherCAT slaves, such as Beckhoff IO modules. All commands are executed through the GenServer
  to ensure state consistency and supervision. Designed for use in Nerves projects or other Elixir applications.

  ## Configuration
  Configure the `ethercat` binary path, ESI directory, and global options via application environment:
  ```elixir
  config :ethercat_ex,
    binary_path: "/usr/bin/ethercat",
    esi_dir: "/etc/ethercat",
    master: "0",           # Default master index
    verbose: false,        # Enable verbose output
    quiet: false,          # Enable quiet output
    force: false           # Force commands
  ```

  ## Periodic Execution
  To run commands periodically (e.g., polling slave states), start the GenServer with a `:poll` option:
  ```elixir
  EthercatEx.Cli.start_link(poll: [command: "slaves", args: [], interval: 1000, callback: &IO.puts/1])
  ```

  ## Example Usage
  ```elixir
  # Start the CLI supervisor
  {:ok, pid} = EthercatEx.Cli.start_link()

  # List all EtherCAT slaves
  {:ok, slaves} = EthercatEx.Cli.list_slaves()

  # Read a digital input (e.g., Beckhoff EL1008)
  {:ok, value} = EthercatEx.Cli.read_sdo(0, "0x6000:01")

  # Write a digital output (e.g., Beckhoff EL2008)
  :ok = EthercatEx.Cli.write_sdo(0, "0x7000:01", 1)

  # Start periodic polling of slaves
  {:ok, pid} = EthercatEx.Cli.start_link(poll: [command: "slaves", interval: 1000, callback: &IO.puts/1])
  ```

  ## Notes
  - Ensure the `ethercat` binary is installed on the target system (e.g., via Buildroot for Nerves).
  - Some commands require specific permissions; consider `chmod u+s /usr/bin/ethercat`.
  - ESI files should be placed in the configured `esi_dir` for full functionality.
  """

  use GenServer
  alias MuonTrap

  # Client API

  @doc """
  Starts the EthercatEx.Cli GenServer for executing `ethercat` commands.

  ## Options
    - `:binary_path` - Path to the `ethercat` binary.
    - `:esi_dir` - Directory containing ESI files.
    - `:master` - Master index or range (e.g., "0", "0-2").
    - `:verbose` - Enable verbose output (boolean).
    - `:quiet` - Enable quiet output (boolean).
    - `:force` - Force command execution (boolean).
    - `:poll` - Periodic command execution, e.g., `[command: "slaves", args: [], interval: 1000, callback: &IO.puts/1]`.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Writes alias addresses to slaves.

  ## Parameters
    - `slave_position`: Integer position or alias (e.g., 0).
    - `alias`: Integer alias address to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def write_alias(slave_position, alias) when is_integer(slave_position) and is_integer(alias) do
    GenServer.call(
      __MODULE__,
      {:command, "alias", ["-p", to_string(slave_position), to_string(alias)]}
    )
  end

  @doc """
  Shows slave configurations.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def list_configs do
    GenServer.call(__MODULE__, {:command, "config", []})
  end

  @doc """
  Performs CRC error register diagnosis.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def diagnose_crc do
    GenServer.call(__MODULE__, {:command, "crc", []})
  end

  @doc """
  Generates slave PDO information in C language.

  Returns `{:ok, c_code}` or `{:error, {code, reason}}`.
  """
  def generate_cstruct do
    GenServer.call(__MODULE__, {:command, "cstruct", []})
  end

  @doc """
  Outputs binary domain process data.

  Returns `{:ok, binary_data}` or `{:error, {code, reason}}`.
  """
  def get_domain_data do
    GenServer.call(__MODULE__, {:command, "data", []})
  end

  @doc """
  Sets the master's debug level.

  ## Parameters
    - `level`: Integer debug level (e.g., 0, 1, 2).

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def set_debug_level(level) when is_integer(level) do
    GenServer.call(__MODULE__, {:command, "debug", [to_string(level)]})
  end

  @doc """
  Shows configured domains.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def list_domains do
    GenServer.call(__MODULE__, {:command, "domains", []})
  end

  @doc """
  Writes an SDO entry to a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `sdo_address`: String SDO address (e.g., "0x7000:01").
    - `value`: Integer or string value to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def write_sdo(slave_position, sdo_address, value)
      when is_integer(slave_position) and is_binary(sdo_address) do
    GenServer.call(
      __MODULE__,
      {:command, "download", ["-p", to_string(slave_position), sdo_address, to_string(value)]}
    )
  end

  @doc """
  Displays Ethernet over EtherCAT (EoE) statistics.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def eoe_stats do
    GenServer.call(__MODULE__, {:command, "eoe", []})
  end

  @doc """
  Reads a file from a slave via FoE.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `filename`: String filename to read.

  Returns `{:ok, file_data}` or `{:error, {code, reason}}`.
  """
  def foe_read(slave_position, filename)
      when is_integer(slave_position) and is_binary(filename) do
    GenServer.call(
      __MODULE__,
      {:command, "foe_read", ["-p", to_string(slave_position), filename]}
    )
  end

  @doc """
  Stores a file on a slave via FoE.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `filename`: String filename to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def foe_write(slave_position, filename)
      when is_integer(slave_position) and is_binary(filename) do
    GenServer.call(
      __MODULE__,
      {:command, "foe_write", ["-p", to_string(slave_position), filename]}
    )
  end

  @doc """
  Outputs the bus topology as a graph.

  Returns `{:ok, graph_data}` or `{:error, {code, reason}}`.
  """
  def bus_topology do
    GenServer.call(__MODULE__, {:command, "graph", []})
  end

  @doc """
  Sets EoE IP parameters for a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `ip_params`: String IP parameters (e.g., "192.168.1.100").

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def set_eoe_ip(slave_position, ip_params)
      when is_integer(slave_position) and is_binary(ip_params) do
    GenServer.call(__MODULE__, {:command, "ip", ["-p", to_string(slave_position), ip_params]})
  end

  @doc """
  Shows master and Ethernet device information.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def master_info do
    GenServer.call(__MODULE__, {:command, "master", []})
  end

  @doc """
  Lists sync managers, PDO assignment, and mapping for a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def list_pdos(slave_position) when is_integer(slave_position) do
    GenServer.call(__MODULE__, {:command, "pdos", ["-p", to_string(slave_position)]})
  end

  @doc """
  Outputs a slave's register contents.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `address`: String register address (e.g., "0x0000").
    - `length`: Integer number of bytes to read.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def read_register(slave_position, address, length)
      when is_integer(slave_position) and is_binary(address) and is_integer(length) do
    GenServer.call(
      __MODULE__,
      {:command, "reg_read", ["-p", to_string(slave_position), address, to_string(length)]}
    )
  end

  @doc """
  Writes data to a slave's registers.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `address`: String register address (e.g., "0x0000").
    - `data`: String or binary data to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def write_register(slave_position, address, data)
      when is_integer(slave_position) and is_binary(address) do
    GenServer.call(
      __MODULE__,
      {:command, "reg_write", ["-p", to_string(slave_position), address, data]}
    )
  end

  @doc """
  Rescans the EtherCAT bus to load ESI files or detect new slaves.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def rescan do
    GenServer.call(__MODULE__, {:command, "rescan", []})
  end

  @doc """
  Lists SDO dictionaries for a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def list_sdos(slave_position) when is_integer(slave_position) do
    GenServer.call(__MODULE__, {:command, "sdos", ["-p", to_string(slave_position)]})
  end

  @doc """
  Outputs a slave's SII contents.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def read_sii(slave_position) when is_integer(slave_position) do
    GenServer.call(__MODULE__, {:command, "sii_read", ["-p", to_string(slave_position)]})
  end

  @doc """
  Writes SII contents to a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `data`: String or binary SII data to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def write_sii(slave_position, data) when is_integer(slave_position) and is_binary(data) do
    GenServer.call(__MODULE__, {:command, "sii_write", ["-p", to_string(slave_position), data]})
  end

  @doc """
  Displays slaves on the EtherCAT bus.

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def list_slaves do
    GenServer.call(__MODULE__, {:command, "slaves", []})
  end

  @doc """
  Reads an SoE IDN from a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `idn`: String IDN (e.g., "0x0000").

  Returns `{:ok, output}` or `{:error, {code, reason}}`.
  """
  def read_soe(slave_position, idn) when is_integer(slave_position) and is_binary(idn) do
    GenServer.call(__MODULE__, {:command, "soe_read", ["-p", to_string(slave_position), idn]})
  end

  @doc """
  Writes an SoE IDN to a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `idn`: String IDN (e.g., "0x0000").
    - `value`: String or binary value to write.

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def write_soe(slave_position, idn, value)
      when is_integer(slave_position) and is_binary(idn) do
    GenServer.call(
      __MODULE__,
      {:command, "soe_write", ["-p", to_string(slave_position), idn, value]}
    )
  end

  @doc """
  Requests application-layer states for slaves.

  ## Parameters
    - `state`: String state to request (e.g., "INIT", "PREOP", "SAFEOP", "OP").

  Returns `:ok` or `{:error, {code, reason}}`.
  """
  def request_state(state) when is_binary(state) do
    GenServer.call(__MODULE__, {:command, "states", [state]})
  end

  @doc """
  Reads an SDO entry from a slave.

  ## Parameters
    - `slave_position`: Integer position of the slave (e.g., 0).
    - `sdo_address`: String SDO address (e.g., "0x6000:01").

  Returns `{:ok, value}` or `{:error, {code, reason}}`.
  """
  def read_sdo(slave_position, sdo_address)
      when is_integer(slave_position) and is_binary(sdo_address) do
    GenServer.call(
      __MODULE__,
      {:command, "upload", ["-p", to_string(slave_position), sdo_address]}
    )
  end

  @doc """
  Shows the EtherCAT CLI version.

  Returns `{:ok, version}` or `{:error, {code, reason}}`.
  """
  def version do
    GenServer.call(__MODULE__, {:command, "version", []})
  end

  @doc """
  Generates slave information XML.

  Returns `{:ok, xml}` or `{:error, {code, reason}}`.
  """
  def generate_xml do
    GenServer.call(__MODULE__, {:command, "xml", []})
  end

  # Server Callbacks

  @doc false
  def init(opts) do
    binary_path =
      Keyword.get(
        opts,
        :binary_path,
        Application.get_env(:ethercat_ex, :binary_path, "/usr/bin/ethercat")
      )

    esi_dir =
      Keyword.get(opts, :esi_dir, Application.get_env(:ethercat_ex, :esi_dir, "/etc/ethercat"))

    master = Keyword.get(opts, :master, Application.get_env(:ethercat_ex, :master, "-"))
    verbose = Keyword.get(opts, :verbose, Application.get_env(:ethercat_ex, :verbose, false))
    quiet = Keyword.get(opts, :quiet, Application.get_env(:ethercat_ex, :quiet, false))
    force = Keyword.get(opts, :force, Application.get_env(:ethercat_ex, :force, false))
    poll = Keyword.get(opts, :poll, nil)

    state = %{
      binary_path: binary_path,
      esi_dir: esi_dir,
      master: master,
      verbose: verbose,
      quiet: quiet,
      force: force,
      poll: poll
    }

    # Schedule periodic command if specified
    if poll do
      schedule_poll(poll)
    end

    {:ok, state}
  end

  @doc false
  def handle_call({:command, command, args}, _from, state) do
    result = run_command(command, args, state)
    {:reply, result, state}
  end

  @doc false
  def handle_info(:poll, %{poll: poll} = state) do
    command = Keyword.get(poll, :command)
    args = Keyword.get(poll, :args, [])
    callback = Keyword.get(poll, :callback, fn _ -> :ok end)

    case run_command(command, args, state) do
      {:ok, output} -> callback.(output)
      # Log error if needed
      {:error, _} -> :ok
    end

    schedule_poll(poll)
    {:noreply, state}
  end

  # Private Functions

  defp run_command(command, args, state) do
    base_args = ["-m", state.master]
    base_args = if state.verbose, do: base_args ++ ["-v"], else: base_args
    base_args = if state.quiet, do: base_args ++ ["-q"], else: base_args
    base_args = if state.force, do: base_args ++ ["-f"], else: base_args

    all_args = base_args ++ [command | args]

    case MuonTrap.cmd(state.binary_path, all_args, stderr_to_stdout: true) do
      {output, 0} ->
        if command in [
             "download",
             "foe_write",
             "reg_write",
             "sii_write",
             "soe_write",
             "states",
             "alias"
           ] do
          :ok
        else
          {:ok, String.trim(output)}
        end

      {error, code} ->
        {:error, {code, String.trim(error)}}
    end
  end

  defp schedule_poll(poll) do
    interval = Keyword.get(poll, :interval, 1000)
    Process.send_after(self(), :poll, interval)
  end
end
