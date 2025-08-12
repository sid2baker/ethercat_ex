defmodule EthercatEx.Slave do
  @moduledoc """
  Module for managing a EtherCAT slave.

  It is started by `EthercatEx.Master` and manages the communication with the slave device.
  """
  use GenServer

  defstruct [:config_ref, :config]

  @type t :: %__MODULE__{
          config_ref: reference(),
          config: Slave.t()
        }

  def start_link(ref, config) do
    GenServer.start_link(__MODULE__, {ref, config})
  end

  def get_config_ref(slave) do
    GenServer.call(slave, :get_config_ref)
  end

  def init({ref, config}) do
    {:ok, %__MODULE__{config_ref: ref, config: config}}
  end

  def handle_call(:get_config_ref, _from, state) do
    {:reply, state.config_ref, state}
  end
end
