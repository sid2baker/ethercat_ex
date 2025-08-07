defmodule EthercatEx.Example do
  @moduledoc """
  Example module demonstrating how to use the EtherCAT Master GenServer.

  This module provides practical examples of setting up and using EtherCAT
  communication with various types of slaves.
  """

  require Logger
  import Bitwise
  alias EthercatEx.{Master, Slave, Domain}

  @doc """
  Basic example of setting up an EtherCAT master with digital I/O slaves.

  This example demonstrates:
  1. Starting the Master GenServer
  2. Requesting a master from EtherLab
  3. Creating a domain
  4. Configuring digital I/O slaves
  5. Activating the master
  6. Starting cyclic communication

  ## Examples

      iex> EthercatEx.Example.basic_io_setup()
      {:ok, %{master_pid: pid, domain_id: 0, input_offset: 0, output_offset: 1}}
  """
  def basic_io_setup do
    # Start the Master GenServer
    {:ok, master_pid} = Master.start_link(name: :example_master, cycle_time_ms: 1)

    try do
      # Request master from EtherLab
      {:ok, _master_ref} = Master.request_master(:example_master)
      Logger.info("EtherCAT master requested successfully")

      # Create a domain for process data
      {:ok, domain_id} = Master.create_domain(:example_master)
      Logger.info("Domain created with ID: #{domain_id}")

      # Scan for slaves to see what's available
      {:ok, slaves} = Master.scan_slaves(:example_master)
      Logger.info("Found #{length(slaves)} slaves on the bus")

      # Configure first slave as input device (assuming it's at position 1)
      # Replace these values with your actual slave's vendor ID and product code
      input_slave_config = configure_input_slave(:example_master, domain_id, 1)

      # Configure second slave as output device (assuming it's at position 2)
      output_slave_config = configure_output_slave(:example_master, domain_id, 2)

      # Activate the master (transitions slaves to operational state)
      :ok = Master.activate(:example_master)
      Logger.info("EtherCAT master activated")

      # Start cyclic task for real-time communication
      {:ok, cyclic_pid} = Master.start_cyclic_task(:example_master)
      Logger.info("Cyclic task started with PID: #{inspect(cyclic_pid)}")

      # Return configuration info
      {:ok,
       %{
         master_pid: master_pid,
         domain_id: domain_id,
         input_offset: input_slave_config[:input_offset],
         output_offset: output_slave_config[:output_offset],
         cyclic_pid: cyclic_pid
       }}
    rescue
      error ->
        Logger.error("Error in basic setup: #{inspect(error)}")
        Master.release(:example_master)
        {:error, error}
    end
  end

  @doc """
  Example of reading digital inputs from the process data.

  ## Parameters

    * `master_name` - Name of the Master GenServer
    * `domain_id` - ID of the domain containing the input data
    * `offset` - Byte offset where input data is located

  ## Examples

      iex> EthercatEx.Example.read_digital_inputs(:example_master, 0, 0)
      [true, false, true, true, false, false, false, false]
  """
  def read_digital_inputs(master_name, domain_id, offset) do
    case Master.read_domain_value(master_name, domain_id, offset) do
      {:ok, byte_value} ->
        # Convert byte to list of 8 boolean values
        for bit <- 0..7 do
          (byte_value &&& 1 <<< bit) != 0
        end

      {:error, reason} ->
        Logger.error("Failed to read digital inputs: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Example of a simple monitoring loop that reads inputs and logs changes.

  This function runs indefinitely, reading input values every 100ms
  and logging any changes detected.

  ## Parameters

    * `master_name` - Name of the Master GenServer
    * `domain_id` - ID of the domain
    * `input_offset` - Offset of input data in the domain

  ## Examples

      # Start monitoring in a separate process
      spawn(fn -> EthercatEx.Example.monitor_inputs(:example_master, 0, 0) end)
  """
  def monitor_inputs(master_name, domain_id, input_offset) do
    Logger.info("Starting input monitoring loop...")
    monitor_loop(master_name, domain_id, input_offset, nil)
  end

  @doc """
  Demonstrates advanced slave configuration with custom PDO mappings.

  This example shows how to configure a slave with specific PDO entries
  and custom sync manager settings.
  """
  def advanced_slave_config do
    {:ok, master_pid} = Master.start_link(name: :advanced_master)

    try do
      {:ok, _master_ref} = Master.request_master(:advanced_master)
      {:ok, domain_id} = Master.create_domain(:advanced_master)

      # Configure a complex slave (e.g., servo drive)
      # These values are examples - replace with your actual slave parameters
      # Example: Beckhoff vendor ID
      vendor_id = 0x000001DD
      # Example product code
      product_code = 0x70120481

      {:ok, slave_config_id} =
        Master.configure_slave(
          :advanced_master,
          # alias
          0,
          # position
          3,
          vendor_id,
          product_code
        )

      # Configure multiple PDO entries for the slave
      pdo_entries = [
        # Control word
        {0x6040, 0x00, domain_id},
        # Target position
        {0x607A, 0x00, domain_id},
        # Target velocity
        {0x60FF, 0x00, domain_id},
        # Status word (input)
        {0x6041, 0x00, domain_id},
        # Position actual value (input)
        {0x6064, 0x00, domain_id}
      ]

      # Register all PDO entries
      offsets =
        Enum.map(pdo_entries, fn {index, subindex, domain} ->
          {:ok, offset} =
            Master.register_pdo_entry(
              :advanced_master,
              slave_config_id,
              index,
              subindex,
              domain
            )

          {index, subindex, offset}
        end)

      Logger.info("PDO entries registered: #{inspect(offsets)}")

      # Activate and start
      :ok = Master.activate(:advanced_master)
      {:ok, _cyclic_pid} = Master.start_cyclic_task(:advanced_master)

      {:ok, %{master_pid: master_pid, domain_id: domain_id, offsets: offsets}}
    rescue
      error ->
        Logger.error("Error in advanced config: #{inspect(error)}")
        Master.release(:advanced_master)
        {:error, error}
    end
  end

  @doc """
  Example cleanup function to properly shutdown EtherCAT communication.

  ## Parameters

    * `master_name` - Name of the Master GenServer to cleanup
  """
  def cleanup(master_name) do
    Logger.info("Cleaning up EtherCAT master: #{master_name}")

    # Stop cyclic task
    case Master.stop_cyclic_task(master_name) do
      :ok -> Logger.info("Cyclic task stopped")
      {:error, :not_running} -> Logger.info("Cyclic task was not running")
      error -> Logger.warning("Error stopping cyclic task: #{inspect(error)}")
    end

    # Release master and stop GenServer
    case Master.release(master_name) do
      :ok -> Logger.info("Master released successfully")
      error -> Logger.error("Error releasing master: #{inspect(error)}")
    end
  end

  @doc """
  Demonstrates error handling and recovery scenarios.

  This example shows how to handle common error conditions and
  implement recovery strategies.
  """
  def error_handling_example do
    master_name = :error_example_master

    {:ok, _master_pid} = Master.start_link(name: master_name)

    try do
      # Try to request master
      result =
        case Master.request_master(master_name) do
          {:ok, _master_ref} ->
            Logger.info("Master requested successfully")
            :ok

          {:error, :MasterNotFound} ->
            Logger.error("No EtherCAT master found - check if EtherLab master is running")
            {:error, :no_master}

          {:error, reason} ->
            Logger.error("Failed to request master: #{inspect(reason)}")
            {:error, reason}
        end

      case result do
        {:error, _} -> result
        :ok -> continue_error_handling_example(master_name)
      end
    after
      cleanup(master_name)
    end
  end

  defp continue_error_handling_example(master_name) do
    # Check master state
    case Master.get_master_state(master_name) do
      {:ok, state} ->
        Logger.info("Master state: #{inspect(state)}")

        if state.slaves_responding == 0 do
          Logger.warning("No slaves responding - check bus connections")
        end

      {:error, reason} ->
        Logger.error("Failed to get master state: #{inspect(reason)}")
    end

    # Scan for slaves with error handling
    case Master.scan_slaves(master_name) do
      {:ok, slaves} ->
        Logger.info("Found #{length(slaves)} slaves")

        # Check for slaves in error state
        error_slaves = Enum.filter(slaves, & &1[:error_flag])

        if length(error_slaves) > 0 do
          Logger.warning("Slaves in error state: #{inspect(error_slaves)}")
        end

      {:error, reason} ->
        Logger.error("Failed to scan slaves: #{inspect(reason)}")
    end
  end

  :ok

  # Private helper functions

  defp configure_input_slave(master_name, domain_id, position) do
    # Example configuration for Beckhoff EL1008 (8-channel digital input)
    # Beckhoff
    vendor_id = 0x00000002
    # EL1008
    product_code = 0x03F03F12

    {:ok, slave_config_id} =
      Master.configure_slave(
        master_name,
        # alias
        0,
        position,
        vendor_id,
        product_code
      )

    # Register PDO entry for digital inputs
    {:ok, input_offset} =
      Master.register_pdo_entry(
        master_name,
        slave_config_id,
        # Digital input object
        0x6000,
        # Subindex for 8-bit input
        0x01,
        domain_id
      )

    Logger.info("Input slave configured at position #{position}, offset: #{input_offset}")
    %{slave_config_id: slave_config_id, input_offset: input_offset}
  end

  defp configure_output_slave(master_name, domain_id, position) do
    # Example configuration for Beckhoff EL2008 (8-channel digital output)
    # Beckhoff
    vendor_id = 0x00000002
    # EL2008
    product_code = 0x07D83F12

    {:ok, slave_config_id} =
      Master.configure_slave(
        master_name,
        # alias
        0,
        position,
        vendor_id,
        product_code
      )

    # Register PDO entry for digital outputs
    {:ok, output_offset} =
      Master.register_pdo_entry(
        master_name,
        slave_config_id,
        # Digital output object
        0x7000,
        # Subindex for 8-bit output
        0x01,
        domain_id
      )

    Logger.info("Output slave configured at position #{position}, offset: #{output_offset}")
    %{slave_config_id: slave_config_id, output_offset: output_offset}
  end

  defp monitor_loop(master_name, domain_id, offset, last_value) do
    case Master.read_domain_value(master_name, domain_id, offset) do
      {:ok, current_value} when current_value != last_value ->
        inputs =
          for bit <- 0..7 do
            (current_value &&& 1 <<< bit) != 0
          end

        Logger.info(
          "Input changed: #{inspect(inputs)} (0x#{Integer.to_string(current_value, 16)})"
        )

        Process.sleep(100)
        monitor_loop(master_name, domain_id, offset, current_value)

      {:ok, current_value} ->
        Process.sleep(100)
        monitor_loop(master_name, domain_id, offset, current_value)

      {:error, reason} ->
        Logger.error("Error reading inputs: #{inspect(reason)}")
        Process.sleep(1000)
        monitor_loop(master_name, domain_id, offset, last_value)
    end
  end
end
