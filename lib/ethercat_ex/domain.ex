defmodule EthercatEx.Domain do
  @moduledoc """
  Module for managing EtherCAT domains.

  A domain represents a memory area that contains process data from multiple slaves.
  This module provides functions for working with domain data and state.
  """
  use GenServer

  defstruct ref: nil,
            binary_template: [],
            data_objects: %{},
            active: false

  @type t :: %__MODULE__{
          ref: reference() | nil,
          binary_template: [{data_object_name(), {offset(), size()}}],
          data_objects: %{data_object_name() => term()},
          active: boolean()
        }

  @type data_object_name :: String.t()
  @type data_object :: {offset(), size()}
  @type offset :: non_neg_integer()
  @type size :: non_neg_integer()

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def activate(domain) do
    GenServer.call(domain, :activate)
  end

  def set_ref(domain, ref) do
    GenServer.call(domain, {:set_ref, ref})
  end

  def get_ref(domain) do
    GenServer.call(domain, :get_ref)
  end

  def add_offset(domain, entry_name, offset, size) do
    GenServer.call(domain, {:add_offset, entry_name, offset, size})
  end

  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def handle_call(:activate, _from, state) do
    # TODO check if binary_template make sense
    binary_template = Enum.reverse(state.binary_template)
    {:reply, :ok, %{state | active: true, binary_template: binary_template}}
  end

  def handle_call({:set_ref, ref}, _from, state) do
    {:reply, :ok, %{state | ref: ref}}
  end

  def handle_call(:get_ref, _from, state) do
    {:reply, state.ref, state}
  end

  def handle_call({:add_offset, entry_name, offset, size}, _from, state) do
    binary_template = [{entry_name, {offset, size}} | state.binary_template]
    {:reply, :ok, %{state | binary_template: binary_template}}
  end

  def handle_info({:data_changed, data}, %{active: true} = state) do
    data_objects =
      match_binary(data, state.binary_template)
      |> IO.inspect(label: "Data Objects")

    # TODO send msg to subscribers
    {:noreply, %{state | data_objects: data_objects}}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "Domain received message")
    {:noreply, state}
  end

  def match_binary(binary, binary_template) do
    Enum.reduce(binary_template, %{}, fn {name, {offset, size}}, acc ->
      <<_::size(offset), segment::size(size), _::binary>> = binary
      Map.put(acc, name, segment)
    end)
  end
end
