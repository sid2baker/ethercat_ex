# Variables
C_SRC_DIR = c_src
PRIV_DIR = priv
NIF_LIB = $(PRIV_DIR)/ethercat_nif.so
LIBETHERCAT = -lethercat
CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(C_SRC_DIR) -O2 -Wall
LDFLAGS = $(LIBETHERCAT) -shared
CC ?= $(CROSSCOMPILE)-gcc

# Targets
all: $(NIF_LIB)

$(NIF_LIB): $(C_SRC_DIR)/ethercat_nif.c
	@mkdir -p $(PRIV_DIR)
	$(CC) $(CFLAGS) -o $(NIF_LIB) $(C_SRC_DIR)/ethercat_nif.c $(LDFLAGS)

clean:
	rm -rf $(PRIV_DIR)
