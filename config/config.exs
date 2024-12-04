import Config

config :ethercat_ex, nif_file: ~c"/ethercat_nif"

import_config "#{Mix.env()}.exs"
