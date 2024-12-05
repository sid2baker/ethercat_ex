import Config

config :ethercat_ex, nif_file: "/ethercat_nif"

import_config "#{Mix.env()}.exs"
