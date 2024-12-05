# Variables
C_SRC_DIR = c_src
PRIV_DIR = priv
NIF_LIB = $(PRIV_DIR)/ethercat_nif.so
FAKE_NIF_LIB = $(PRIV_DIR)/fakeethercat_nif.so

CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(C_SRC_DIR) -O2 -Wall
CC ?= $(CROSSCOMPILE)-gcc

# Targets
all: $(NIF_LIB) $(FAKE_NIF_LIB)

$(NIF_LIB): $(C_SRC_DIR)/ethercat_nif.c
	@mkdir -p $(PRIV_DIR)
	$(CC) $(CFLAGS) -o $(NIF_LIB) $(C_SRC_DIR)/ethercat_nif.c -lethercat -shared

$(FAKE_NIF_LIB): $(C_SRC_DIR)/ethercat_nif.c
	@mkdir -p $(PRIV_DIR)
	$(CC) $(CFLAGS) -o $(FAKE_NIF_LIB) $(C_SRC_DIR)/ethercat_nif.c -lfakeethercat -shared

clean:
	rm -rf $(PRIV_DIR)
