defmodule EthercatEx.Slave do
  @moduledoc """
  Module for managing a EtherCAT slave.

  It is started by `EthercatEx.Master` and manages the communication with the slave device.
  """
  use GenServer

  defstruct [:ref, :config]

  @type t :: %__MODULE__{
          ref: reference(),
          config: Slave.t()
        }

  def start_link(ref, config) do
    GenServer.start_link(__MODULE__, {ref, config})
  end

  def init({ref, config}) do
    {:ok, %__MODULE__{ref: ref, config: config}}
  end
end
