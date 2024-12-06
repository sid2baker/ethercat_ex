import Config

config :ethercat_ex, nif_lib_name: "ethercat_nif"

import_config "#{Mix.env()}.exs"
