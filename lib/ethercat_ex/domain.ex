defmodule EthercatEx.Domain do
  @moduledoc """
  Module for managing EtherCAT domains.

  A domain represents a memory area that contains process data from multiple slaves.
  This module provides functions for working with domain data and state.
  """
  use GenServer

  defstruct [:ref]

  @type t :: %__MODULE__{
          ref: reference()
        }

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def set_ref(domain, ref) do
    GenServer.call(domain, {:set_ref, ref})
  end

  def get_ref(domain) do
    GenServer.call(domain, :get_ref)
  end

  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def handle_call({:set_ref, ref}, _from, state) do
    {:reply, :ok, %{state | ref: ref}}
  end

  def handle_call(:get_ref, _from, state) do
    {:reply, state.ref, state}
  end
end
