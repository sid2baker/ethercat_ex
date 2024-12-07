PREFIX = $(MIX_APP_PATH)/priv
BUILD = $(MIX_APP_PATH)/obj

DEFAULT_TARGETS ?= $(PREFIX) $(PREFIX)/ethercat_nif.so

ERL_CFLAGS ?= -I$(ERTS_INCLUDE_DIR)
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic -std=gnu99
CC ?= $(CROSSCOMPILE)-gcc

# Enable for debug messages
# CFLAGS += -DDEBUG

ifeq ($(origin CROSSCOMPILE), undefined)
	LDFLAGS += -lfakeethercat -lethercat
else
	LDFLAGS += -lethercat
endif

ifeq ($(MIX_ENV),test)
	DEFAULT_TARGETS += $(PREFIX)/fakeethercat_nif.so
endif

calling_from_make:
	mix compile

all: install

install: $(BUILD) $(DEFAULT_TARGETS)

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(PREFIX)/ethercat_nif.so: $(BUILD)/ethercat_nif.o
	@echo " LD $(notdir $@)"
	$(CC) $^ -shared  $(ERL_LDFLAGS) $(LDFLAGS) -o $@
	$(call update_perms, $@)

$(PREFIX)/fakeethercat_nif.so: $(BUILD)/ethercat_nif.o
	@echo " LD $(notdir $@)"
	$(CC) $^ -shared  $(ERL_LDFLAGS) $(LDFLAGS) -o $@
	$(call update_perms, $@)

$(PREFIX) $(BUILD):
	mkdir -p $@

mix_clean:
	$(RM) $(PREFIX)/* $(BUILD)/*

clean:
	mix clean

.PHONY: all clean mix_clean calling_from_make install
