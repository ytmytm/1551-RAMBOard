# Makefile for 1551 RAMBOard FirstBank project
# Based on build.bat

# Configuration
KICKASS_JAR = tools/KickAss.jar
ASM_FILE = rampatch.asm
OUTPUT = rampatch.prg
LOG_FILE = rampatch.log
ROM_DIR = rom
ROM_FILE = $(ROM_DIR)/1551.318008-01.bin
SUPERDOS_ROM_FILE = $(ROM_DIR)/super_dos_1551.bin
ROM_URL = https://www.zimmers.net/anonftp/pub/cbm/firmware/drives/new/1551/1551.318008-01.bin
SUPERDOS_ROM_URL = https://plus4world.powweb.com/dl/utils/s/super_dos_1551.rom
LIB_DIR = lib

# Patched ROM files
PATCHED_ROM = 1551.318008-01-patched.bin
SUPERDOS_PATCHED_ROM = super_dos_1551-patched.bin
# 64K ROM images for EPROM (27C512/27E512)
ROM_64K = 1551.318008-01-64k.bin
SUPERDOS_ROM_64K = super_dos_1551-64k.bin
# Fastloader wedge (optional, requires acme)
HYPARAM_PRG = hyparam_1551.prg
HYPARAM_SRC = src/hypainstall14f0.s

# Build outputs (generated files; source ROMs in rom/ are kept)
BUILD_OUTPUTS = \
	$(OUTPUT) \
	$(LOG_FILE) \
	rampatch.sym \
	rampatch.vs \
	rampatch-super.log \
	rampatch-super.prg \
	$(PATCHED_ROM) \
	$(ROM_64K) \
	$(SUPERDOS_PATCHED_ROM) \
	$(SUPERDOS_ROM_64K) \
	$(HYPARAM_PRG)

# KickAss ROM selection (pass one of these, not both)
DEFINE_STOCK = -define ROM1551
DEFINE_SUPER = -define SUPERDOS1551
KICKASS = java -jar $(KICKASS_JAR) $(ASM_FILE) -vicesymbols -showmem -afo -symbolfiledir . -libdir $(LIB_DIR)

# Deliverables built by "make" / "make all"
ALL_OUTPUTS = \
	$(PATCHED_ROM) \
	$(ROM_64K) \
	$(SUPERDOS_PATCHED_ROM) \
	$(SUPERDOS_ROM_64K) \
	$(HYPARAM_PRG)

.DEFAULT_GOAL := all

# Default target — build every deliverable
all: $(ALL_OUTPUTS)
	@echo "All outputs built:"
	@for f in $(ALL_OUTPUTS); do echo "  $$f"; done

# Legacy .prg output (stock ROM build)
$(OUTPUT): $(PATCHED_ROM)

# Target to build the patched 32K ROM (stock 1551 base)
$(PATCHED_ROM): $(ASM_FILE) $(KICKASS_JAR) $(ROM_FILE)
	@echo "Building patched 32K ROM $(PATCHED_ROM)..."
	$(KICKASS) $(DEFINE_STOCK) -log $(LOG_FILE) -o $(OUTPUT)

# Target to build the patched 32K ROM (SuperDOS base)
$(SUPERDOS_PATCHED_ROM): $(ASM_FILE) $(KICKASS_JAR) $(SUPERDOS_ROM_FILE)
	@echo "Building patched 32K ROM $(SUPERDOS_PATCHED_ROM)..."
	$(KICKASS) $(DEFINE_SUPER) -log rampatch-super.log -o rampatch-super.prg

# Alias for SuperDOS patched ROM / 64K image
superrom: $(SUPERDOS_ROM_64K)

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

# Download SuperDOS ROM if it doesn't exist (saved as .bin; URL uses .rom extension)
$(SUPERDOS_ROM_FILE):
	@mkdir -p $(ROM_DIR)
	@if [ -f $(ROM_DIR)/super_dos_1551.rom ] && [ ! -f $@ ]; then \
		echo "Renaming $(ROM_DIR)/super_dos_1551.rom -> $@"; \
		mv $(ROM_DIR)/super_dos_1551.rom $@; \
	fi
	@if [ -f $@ ]; then \
		: ; \
	else \
		echo "Downloading SuperDOS 1551 ROM from $(SUPERDOS_ROM_URL)..."; \
		if command -v curl >/dev/null 2>&1; then \
			curl -L -o $@ $(SUPERDOS_ROM_URL); \
		elif command -v wget >/dev/null 2>&1; then \
			wget -O $@ $(SUPERDOS_ROM_URL); \
		else \
			echo "Error: Neither curl nor wget found. Please download $@ manually from $(SUPERDOS_ROM_URL)"; \
			exit 1; \
		fi; \
	fi
	@if [ ! -f $@ ]; then \
		echo "Error: Failed to obtain $(SUPERDOS_ROM_FILE)"; \
		exit 1; \
	fi

# Ensure KickAss jar exists
$(KICKASS_JAR):
	@if [ ! -f $(KICKASS_JAR) ]; then \
		echo "Error: $(KICKASS_JAR) not found. Please download it and place it in the tools/ directory."; \
		exit 1; \
	fi

# Clean all build outputs (keeps source ROMs in rom/)
clean:
	rm -f $(BUILD_OUTPUTS)
	@echo "Cleaned build outputs"

# Alias for clean
distclean: clean

# Show available targets
help:
	@echo "1551 RAMBOard FirstBank — make targets"
	@echo ""
	@echo "Build:"
	@echo "  make / make all          Build all outputs ($(words $(ALL_OUTPUTS)) files)"
	@echo "  make $(PATCHED_ROM)"
	@echo "                           Patched 32K ROM (stock 1551 base)"
	@echo "  make $(ROM_64K)"
	@echo "                           64K EPROM image (stock ROM + patched ROM)"
	@echo "  make superrom            Patched SuperDOS 32K ROM + 64K EPROM image"
	@echo "  make $(SUPERDOS_PATCHED_ROM)"
	@echo "                           Patched 32K ROM (SuperDOS 40-track base)"
	@echo "  make $(SUPERDOS_ROM_64K)"
	@echo "                           64K EPROM image (SuperDOS + patched ROM)"
	@echo "  make $(HYPARAM_PRG)      HypaRAM fastloader wedge (requires acme)"
	@echo ""
	@echo "Test (VICE xplus4 with RAM expansion at \$$8000):"
	@echo "  make test                Stock patched ROM"
	@echo "  make test-super          SuperDOS patched ROM"
	@echo ""
	@echo "Emulator:"
	@echo "  make vice-setup          Install VICE data files to \$$HOME/.local/share/vice"
	@echo "  make xplus4              Start VICE xplus4"
	@echo "  make xplus4-disk DISK=path/to/disk.d64"
	@echo ""
	@echo "Other:"
	@echo "  make clean               Remove all build outputs"
	@echo "  make help                Show this help"

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
.PHONY: all clean distclean help vice-setup xplus4 xplus4-disk test test-super superrom

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

# 64K ROM image for EPROM (27C512/27E512), SuperDOS variant
# Layout:
# - First 16K: $ff (EPROM neutral)
# - Next 16K: SuperDOS 1551 ROM
# - Upper 32K: patched SuperDOS ROM
$(SUPERDOS_ROM_64K): $(SUPERDOS_PATCHED_ROM) $(SUPERDOS_ROM_FILE)
	@echo "Building 64K ROM image $(SUPERDOS_ROM_64K)..."
	@dd if=/dev/zero bs=16384 count=1 2>/dev/null | tr '\000' '\377' > $(SUPERDOS_ROM_64K) || \
	 (printf '\377%.0s' {1..16384} > $(SUPERDOS_ROM_64K) 2>/dev/null || \
	  (echo "Error: Need dd or printf to create 64K ROM" && exit 1))
	@dd if=$(SUPERDOS_ROM_FILE) bs=16384 count=1 >> $(SUPERDOS_ROM_64K) 2>/dev/null || \
	 (head -c 16384 $(SUPERDOS_ROM_FILE) >> $(SUPERDOS_ROM_64K) 2>/dev/null || \
	  (echo "Error: Failed to append SuperDOS ROM" && exit 1))
	@dd if=$(SUPERDOS_PATCHED_ROM) bs=32768 count=1 >> $(SUPERDOS_ROM_64K) 2>/dev/null || \
	 (head -c 32768 $(SUPERDOS_PATCHED_ROM) >> $(SUPERDOS_ROM_64K) 2>/dev/null || \
	  (echo "Error: Failed to append patched SuperDOS ROM" && exit 1))
	@SIZE=$$(wc -c < $(SUPERDOS_ROM_64K) 2>/dev/null || stat -f%z $(SUPERDOS_ROM_64K) 2>/dev/null || stat -c%s $(SUPERDOS_ROM_64K) 2>/dev/null || echo 0); \
	 if [ $$SIZE -ne 65536 ]; then \
		echo "Error: $(SUPERDOS_ROM_64K) size is $$SIZE, expected 65536"; \
		rm -f $(SUPERDOS_ROM_64K); \
		exit 1; \
	 fi
	@echo "64K ROM image created: $(SUPERDOS_ROM_64K)"

$(HYPARAM_PRG): $(HYPARAM_SRC)
	@command -v acme >/dev/null 2>&1 || (echo "Error: acme required to build $(HYPARAM_PRG)" && exit 1)
	@echo "Building fastloader wedge $(HYPARAM_PRG)..."
	@cd src && acme hypainstall14f0.s
	@test -f src/$(HYPARAM_PRG) || (echo "Error: acme did not produce $(HYPARAM_PRG)" && exit 1)
	@mv src/$(HYPARAM_PRG) $(HYPARAM_PRG)
	@echo "Fastloader wedge created: $(HYPARAM_PRG)"

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

# Run test with patched SuperDOS 32K ROM and RAM expansion enabled
test-super: $(SUPERDOS_PATCHED_ROM) vice-setup
	@echo "Starting VICE xplus4 with patched SuperDOS 32K ROM and RAM expansion..."
	@ROM_PATH="$$(pwd)/$(SUPERDOS_PATCHED_ROM)" && \
	if [ -f /usr/local/bin/xa ]; then \
		XA_PATH="/usr/local/bin"; \
	else \
		XA_PATH="$$(cd $(VICE_XA_BIN) && pwd)"; \
	fi && \
	export PATH="$$XA_PATH:$$PATH" && \
	export DISPLAY=$${DISPLAY:-localhost:0.0} && \
	$(VICE_BINARY) -dos1551 "$$ROM_PATH" -drive8ram8000
