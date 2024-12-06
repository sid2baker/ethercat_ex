defmodule EthercatEx.Nif do
  @moduledoc false

  @on_load :load_nif
  def load_nif do
    nif_file =
      Path.join([:code.priv_dir(:ethercat_ex), Application.get_env(:ethercat_ex, :nif_file)])

    case :erlang.load_nif(nif_file, 0) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      {:error, reason} -> IO.puts("Failed to load nif: #{inspect(reason)}")
    end
  end

  def request_master(), do: :erlang.nif_error(:nif_not_loaded)
  def master_create_domain(_name), do: :erlang.nif_error(:nif_not_loaded)
  def master_remove_domain(_name), do: :erlang.nif_error(:nif_not_loaded)

  def master_get_slave(_index), do: :erlang.nif_error(:nif_not_loaded)

  def master_slave_config(_alias, _position, _vendor_id, _product_code),
    do: :erlang.nif_error(:nif_not_loaded)

  def slave_config_pdos(_config), do: :erlang.nif_error(:nif_not_loaded)
  def master_activate, do: :erlang.nif_error(:nif_not_loaded)
  def master_queue_all_domains, do: :erlang.nif_error(:nif_not_laded)

  def master_send, do: :erlang.nif_error(:nif_not_loaded)
  def run, do: :erlang.nif_error(:nif_not_loaded)

  # Add additional Elixir wrappers for NIF functions
end
