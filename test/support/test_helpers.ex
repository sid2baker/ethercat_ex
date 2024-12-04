defmodule EthercatEx.TestHelpers do
  def get_library_path!(library_name) do
    {output, _exit_code} = System.cmd("ldconfig", ["-p"])

    output
    |> String.split("\n")
    |> Enum.filter(fn line -> String.contains?(line, library_name) end)
    |> List.first()
    |> String.split(" => ")
    |> List.to_tuple()
    |> elem(1)
  end
end
