defmodule EthercatEx.Nif do
  @moduledoc false

    @on_load :load_nif
    def load_nif do
      nif_file = ~c"#{:code.priv_dir(:ethercat_ex)}/ethercat_nif"

      case :erlang.load_nif(nif_file, 0) do
        :ok -> :ok
        {:error, {:reload, _}} -> :ok
        {:error, reason} -> IO.puts("Failed to load nif: #{inspect(reason)}")
      end
    end

  def request_master do
    :erlang.nif_error(:nif_not_loaded)
  end

  # Add additional Elixir wrappers for NIF functions
end
