# Variables
C_SRC_DIR = c_src
PRIV_DIR = priv
ETHER_NIF_LIB = $(PRIV_DIR)/ethercat_nif.so
FAKE_NIF_LIB = $(PRIV_DIR)/fakeethercat_nif.so

CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(C_SRC_DIR) -O2 -Wall
LDFLAGS_ETHER = -lethercat -shared
LDFLAGS_FAKE = -lfakeethercat -shared
CC ?= $(CROSSCOMPILE)-gcc

# Targets
all: $(ETHER_NIF_LIB) $(FAKE_NIF_LIB)

$(ETHER_NIF_LIB): $(C_SRC_DIR)/ethercat_nif.c
	@mkdir -p $(PRIV_DIR)
	$(CC) $(CFLAGS) -o $(ETHER_NIF_LIB) $(C_SRC_DIR)/ethercat_nif.c $(LDFLAGS_ETHER)

$(FAKE_NIF_LIB): $(C_SRC_DIR)/ethercat_nif.c
	@mkdir -p $(PRIV_DIR)
	$(CC) $(CFLAGS) -o $(FAKE_NIF_LIB) $(C_SRC_DIR)/ethercat_nif.c $(LDFLAGS_FAKE)

clean:
	rm -rf $(PRIV_DIR)
