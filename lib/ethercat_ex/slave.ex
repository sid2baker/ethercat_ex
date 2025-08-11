defmodule EthercatEx.Slave do
  @moduledoc """
  Module for managing a EtherCAT slave.

  It is started by `EthercatEx.Master` and manages the communication with the slave device.
  """
  use GenServer

  alias __MODULE__

  defstruct [:config]

  @type __MODULE__ :: %{
          config: Slave.t()
        }

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    {:ok, %__MODULE__{config: config}}
  end
end
