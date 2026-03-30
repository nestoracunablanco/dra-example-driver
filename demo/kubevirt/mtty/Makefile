# Makefile for building the mtty kernel module

# Module name
obj-m += mtty.o

# Kernel build directory
KDIR ?= /lib/modules/$(shell uname -r)/build

# Current directory
PWD := $(shell pwd)

# Default target: build the module
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

# Clean target: remove all generated files
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers .*.cmd
	rm -rf .tmp_versions

# Load target: insert the module temporarily (non-persistent)
load:
	@if [ ! -f mtty.ko ]; then \
		echo "Error: mtty.ko not found. Run 'make' first to build the module."; \
		exit 1; \
	fi
	sudo modprobe vfio
	sudo modprobe mdev
	sudo insmod mtty.ko
	@echo "Module loaded successfully. Use 'make unload' to remove it."

# Unload target: remove the module
unload:
	sudo rmmod mtty
	@echo "Module unloaded successfully."

# Status target: check if module is loaded
status:
	@lsmod | grep mtty || echo "Module is not loaded"

# Help target
help:
	@echo "Makefile for mtty kernel module"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build the mtty kernel module (default)"
	@echo "  clean   - Remove all generated files"
	@echo "  load    - Load the module temporarily (non-persistent, requires sudo)"
	@echo "  unload  - Unload the module (requires sudo)"
	@echo "  status  - Check if the module is currently loaded"
	@echo "  help    - Show this help message"

.PHONY: all clean install help
