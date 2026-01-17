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

# Patched ROM file
PATCHED_ROM = 1551.318008-01-patched.bin

# 64K ROM image for EPROM (27C512/27E512)
ROM_64K = 1551.318008-01-64k.bin

# Fastloader wedge (optional, requires acme)
HYPARAM_PRG = hyparam_1551.prg
HYPARAM_SRC = src/hypainstall14f0.s

# Default target
all: $(OUTPUT) $(ROM_64K) $(HYPARAM_PRG)

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
	rm -f $(OUTPUT) $(LOG_FILE) rampatch.sym rampatch.vs $(HYPARAM_PRG)
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
	@if [ -f /usr/local/bin/xa ]; then \
		XA_PATH="/usr/local/bin"; \
	else \
		XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)"; \
	fi && \
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
	@if [ -f /usr/local/bin/xa ]; then \
		XA_PATH="/usr/local/bin"; \
	else \
		XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)"; \
	fi && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY) "$(DISK)"

# Phony targets
.PHONY: all clean distclean vice-setup xplus4 xplus4-disk test

# Target to build the patched 32K ROM
$(PATCHED_ROM): $(ASM_FILE) $(KICKASS_JAR) $(ROM_FILE)
	@echo "Building patched 32K ROM $(PATCHED_ROM)..."
	java -jar $(KICKASS_JAR) $(ASM_FILE) -log $(LOG_FILE) -vicesymbols -showmem -afo -symbolfiledir . -libdir $(LIB_DIR)

# 64K ROM image for EPROM (27C512/27E512)
# Layout:
# - First 16K: $ff (EPROM neutral)
# - Next 16K: stock 1551 ROM
# - Upper 32K: patched 1551 ROM
$(ROM_64K): $(PATCHED_ROM) $(ROM_FILE)
	@echo "Building 64K ROM image $(ROM_64K)..."
	@# Create 16K of $ff bytes (EPROM neutral)
	@dd if=/dev/zero bs=16384 count=1 2>/dev/null | tr '\000' '\377' > $(ROM_64K) || \
	 (printf '\377%.0s' {1..16384} > $(ROM_64K) 2>/dev/null || \
	  (echo "Error: Need dd or printf to create 64K ROM" && exit 1))
	@# Append 16K of stock ROM
	@dd if=$(ROM_FILE) bs=16384 count=1 >> $(ROM_64K) 2>/dev/null || \
	 (head -c 16384 $(ROM_FILE) >> $(ROM_64K) 2>/dev/null || \
	  (echo "Error: Failed to append stock ROM" && exit 1))
	@# Append 32K of patched ROM
	@dd if=$(PATCHED_ROM) bs=32768 count=1 >> $(ROM_64K) 2>/dev/null || \
	 (head -c 32768 $(PATCHED_ROM) >> $(ROM_64K) 2>/dev/null || \
	  (echo "Error: Failed to append patched ROM" && exit 1))
	@# Verify size is 64K
	@SIZE=$$(wc -c < $(ROM_64K) 2>/dev/null || stat -f%z $(ROM_64K) 2>/dev/null || stat -c%s $(ROM_64K) 2>/dev/null || echo 0); \
	 if [ $$SIZE -ne 65536 ]; then \
		echo "Error: $(ROM_64K) size is $$SIZE, expected 65536"; \
		rm -f $(ROM_64K); \
		exit 1; \
	 fi
	@echo "64K ROM image created: $(ROM_64K)"

$(HYPARAM_PRG): $(HYPARAM_SRC)
	@if command -v acme >/dev/null 2>&1; then \
		echo "Building fastloader wedge $(HYPARAM_PRG)..."; \
		cd src && acme hypainstall14f0.s; \
		if [ -f $(HYPARAM_PRG) ]; then \
			mv $(HYPARAM_PRG) ../$(HYPARAM_PRG); \
			echo "Fastloader wedge created: $(HYPARAM_PRG)"; \
		else \
			echo "Warning: acme did not produce $(HYPARAM_PRG)"; \
		fi; \
	else \
		echo "Note: acme not found, skipping fastloader wedge build"; \
		echo "      Install acme to build $(HYPARAM_PRG)"; \
	fi

# Run test with patched 32K ROM and RAM expansion enabled
test: $(PATCHED_ROM) vice-setup
	@echo "Starting VICE xplus4 with patched 32K ROM and RAM expansion..."
	@ROM_PATH="$$(pwd)/$(PATCHED_ROM)" && \
	if [ -f /usr/local/bin/xa ]; then \
		XA_PATH="/usr/local/bin"; \
	else \
		XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)"; \
	fi && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY) -dos1551 "$$ROM_PATH" -drive8ram8000

