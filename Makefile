# Makefile for 1551 RAMBOard FirstBank project
# Based on build.bat

# Configuration
KICKASS_JAR = tools/KickAss.jar
ASM_FILE = rampatch.asm
OUTPUT = rampatch.prg
LOG_FILE = rampatch.log
ROM_DIR = rom
ROM_FILE = $(ROM_DIR)/1551.318008-01.bin
ROM_URL = https://www.zimmers.net/anonftp/pub/cbm/firmware/drives/new/1551/1551.318008-01.bin
LIB_DIR = lib

# Default target
all: $(OUTPUT)

# Main build target
$(OUTPUT): $(ASM_FILE) $(KICKASS_JAR) $(ROM_FILE)
	@echo "Building $(OUTPUT)..."
	java -jar $(KICKASS_JAR) $(ASM_FILE) -log $(LOG_FILE) -o $(OUTPUT) -vicesymbols -showmem -afo -symbolfiledir . -libdir $(LIB_DIR)

# Download ROM file if it doesn't exist
$(ROM_FILE):
	@echo "Downloading 1551 ROM from $(ROM_URL)..."
	@mkdir -p $(ROM_DIR)
	@if command -v curl >/dev/null 2>&1; then \
		curl -L -o $(ROM_FILE) $(ROM_URL); \
	elif command -v wget >/dev/null 2>&1; then \
		wget -O $(ROM_FILE) $(ROM_URL); \
	else \
		echo "Error: Neither curl nor wget found. Please download $(ROM_FILE) manually from $(ROM_URL)"; \
		exit 1; \
	fi
	@if [ ! -f $(ROM_FILE) ]; then \
		echo "Error: Failed to download $(ROM_FILE)"; \
		exit 1; \
	fi

# Ensure KickAss jar exists
$(KICKASS_JAR):
	@if [ ! -f $(KICKASS_JAR) ]; then \
		echo "Error: $(KICKASS_JAR) not found. Please download it and place it in the tools/ directory."; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	rm -f $(OUTPUT) $(LOG_FILE) rampatch.sym rampatch.vs
	@echo "Cleaned build artifacts"

# Clean everything (but keep ROM)
distclean: clean
	@echo "Cleaned all build artifacts"

# VICE xplus4 configuration
VICE_DIR = tools/vice
VICE_SRC = $(VICE_DIR)/vice
VICE_INSTALL = $(VICE_DIR)/install
VICE_BINARY = $(VICE_SRC)/src/xplus4
VICE_DATA = $(VICE_SRC)/data
VICE_HOME = $(HOME)/.local/share/vice
VICE_STATE = $(HOME)/.local/state/vice
VICE_XA_BIN = tools/xa/bin

# Setup VICE directories and files
vice-setup: $(VICE_BINARY)
	@echo "Setting up VICE xplus4..."
	@mkdir -p $(VICE_HOME) $(VICE_STATE)
	@if [ -d "$(VICE_DATA)/PLUS4" ]; then \
		mkdir -p $(VICE_HOME)/PLUS4; \
		cp -n $(VICE_DATA)/PLUS4/*.bin $(VICE_HOME)/PLUS4/ 2>/dev/null || true; \
		cp -n $(VICE_DATA)/PLUS4/*.vkm $(VICE_HOME)/PLUS4/ 2>/dev/null || true; \
		cp -n $(VICE_DATA)/PLUS4/*.vpl $(VICE_HOME)/PLUS4/ 2>/dev/null || true; \
		cp -n $(VICE_DATA)/PLUS4/*.vrs $(VICE_HOME)/PLUS4/ 2>/dev/null || true; \
		echo "VICE ROM and keymap files copied to $(VICE_HOME)/PLUS4/"; \
	fi
	@if [ -d "$(VICE_INSTALL)/share/vice" ]; then \
		mkdir -p $(VICE_HOME); \
		cp -rn $(VICE_INSTALL)/share/vice/* $(VICE_HOME)/ 2>/dev/null || true; \
		echo "VICE system files installed to $(VICE_HOME)/"; \
	fi
	@echo "VICE setup complete!"

# Run xplus4 emulator
xplus4: vice-setup
	@echo "Starting VICE xplus4 emulator..."
	@XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)" && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY)

# Run xplus4 with specific disk image
xplus4-disk: vice-setup
	@if [ -z "$(DISK)" ]; then \
		echo "Usage: make xplus4-disk DISK=path/to/disk.d64"; \
		exit 1; \
	fi
	@echo "Starting VICE xplus4 with disk: $(DISK)"
	@XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)" && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY) "$(DISK)"

# Phony targets
.PHONY: all clean distclean vice-setup xplus4 xplus4-disk test

# Patched ROM file
PATCHED_ROM = 1551.318008-01-patched.bin

# Target to build the patched 32K ROM
$(PATCHED_ROM): $(ASM_FILE) $(KICKASS_JAR) $(ROM_FILE)
	@echo "Building patched 32K ROM $(PATCHED_ROM)..."
	java -jar $(KICKASS_JAR) $(ASM_FILE) -log $(LOG_FILE) -vicesymbols -showmem -afo -symbolfiledir . -libdir $(LIB_DIR)

# Run test with patched 32K ROM and RAM expansion enabled
test: $(PATCHED_ROM) vice-setup
	@echo "Starting VICE xplus4 with patched 32K ROM and RAM expansion..."
	@ROM_PATH="$$(pwd)/$(PATCHED_ROM)" && \
	XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)" && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY) -dos1551 "$$ROM_PATH" -drive8ram8000

