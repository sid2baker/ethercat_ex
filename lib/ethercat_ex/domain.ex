defmodule EthercatEx.Domain do
  @moduledoc """
  Module for managing EtherCAT domains.

  A domain represents a memory area that contains process data from multiple slaves.
  This module provides functions for working with domain data and state.
  """

  import Bitwise
  alias EthercatEx.Nif

  @type domain_ref :: reference()
  @type domain_state :: %{
          working_counter: non_neg_integer(),
          wc_state: atom()
        }

  @doc """
  Processes the domain, updating input data from the network.

  This function should be called in the cyclic task before reading input data.
  """
  @spec process(domain_ref()) :: :ok | {:error, term()}
  def process(domain_ref) do
    Nif.domain_process(domain_ref)
  end

  @doc """
  Queues the domain for sending output data to the network.

  This function should be called in the cyclic task after writing output data.
  """
  @spec queue(domain_ref()) :: :ok | {:error, term()}
  def queue(domain_ref) do
    Nif.domain_queue(domain_ref)
  end

  @doc """
  Gets the current state of a domain.

  Returns information about working counter and state.
  """
  @spec get_state(domain_ref()) :: {:ok, domain_state()} | {:error, term()}
  def get_state(domain_ref) do
    case Nif.domain_state(domain_ref) do
      {:ok, state} -> {:ok, state}
      error -> error
    end
  end

  @doc """
  Reads a byte value from the domain at the specified offset.

  ## Parameters

    * `domain_ref` - Reference to the domain
    * `offset` - Byte offset in the domain data

  ## Examples

      iex> EthercatEx.Domain.read_u8(domain_ref, 0)
      255
  """
  @spec read_u8(domain_ref(), non_neg_integer()) :: integer()
  def read_u8(domain_ref, offset) do
    Nif.get_domain_value(domain_ref, offset)
  end

  @doc """
  Reads a 16-bit unsigned integer from the domain (little-endian).

  ## Parameters

    * `domain_ref` - Reference to the domain
    * `offset` - Byte offset in the domain data
  """
  @spec read_u16(domain_ref(), non_neg_integer()) :: integer()
  def read_u16(domain_ref, offset) do
    low_byte = Nif.get_domain_value(domain_ref, offset)
    high_byte = Nif.get_domain_value(domain_ref, offset + 1)
    high_byte <<< 8 ||| low_byte
  end

  @doc """
  Reads a 32-bit unsigned integer from the domain (little-endian).

  ## Parameters

    * `domain_ref` - Reference to the domain
    * `offset` - Byte offset in the domain data
  """
  @spec read_u32(domain_ref(), non_neg_integer()) :: integer()
  def read_u32(domain_ref, offset) do
    byte0 = Nif.get_domain_value(domain_ref, offset)
    byte1 = Nif.get_domain_value(domain_ref, offset + 1)
    byte2 = Nif.get_domain_value(domain_ref, offset + 2)
    byte3 = Nif.get_domain_value(domain_ref, offset + 3)

    byte3 <<< 24 ||| byte2 <<< 16 ||| byte1 <<< 8 ||| byte0
  end

  @doc """
  Reads a single bit from the domain data.

  ## Parameters

    * `domain_ref` - Reference to the domain
    * `offset` - Byte offset in the domain data
    * `bit_position` - Bit position within the byte (0-7)

  ## Examples

      iex> EthercatEx.Domain.read_bit(domain_ref, 0, 3)
      true
  """
  @spec read_bit(domain_ref(), non_neg_integer(), 0..7) :: boolean()
  def read_bit(domain_ref, offset, bit_position) when bit_position in 0..7 do
    byte_value = Nif.get_domain_value(domain_ref, offset)
    (byte_value &&& 1 <<< bit_position) != 0
  end

  @doc """
  Reads multiple bits as a boolean list from the domain data.

  ## Parameters

    * `domain_ref` - Reference to the domain
    * `offset` - Byte offset in the domain data
    * `bit_count` - Number of bits to read (1-8)

  ## Examples

      iex> EthercatEx.Domain.read_bits(domain_ref, 0, 4)
      [true, false, true, false]
  """
  @spec read_bits(domain_ref(), non_neg_integer(), 1..8) :: [boolean()]
  def read_bits(domain_ref, offset, bit_count) when bit_count in 1..8 do
    byte_value = Nif.get_domain_value(domain_ref, offset)

    for bit_pos <- 0..(bit_count - 1) do
      (byte_value &&& 1 <<< bit_pos) != 0
    end
  end

  @doc """
  Gets raw domain data pointer (for advanced use cases).

  Note: This returns a raw pointer and should be used with caution.
  """
  @spec get_data_pointer(domain_ref()) :: {:ok, binary()} | {:error, term()}
  def get_data_pointer(domain_ref) do
    case Nif.domain_data(domain_ref) do
      {:ok, pointer} -> {:ok, pointer}
      error -> error
    end
  end

  # Future functions for writing data would go here:
  # write_u8/3, write_u16/3, write_u32/3, write_bit/4, etc.
  # These would require additional NIF functions to be implemented
end
