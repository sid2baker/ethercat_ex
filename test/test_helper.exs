# FAKE_EC_NAME=FakeEtherCAT is default
master_location = Path.join(System.tmp_dir!(), "FakeEtherCAT")

# Register a callback to delete the file after all tests
ExUnit.after_suite(fn _ ->
  nil
  # File.rm_rf!(master_location)
end)

ExUnit.start()
