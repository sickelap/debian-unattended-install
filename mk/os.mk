ifeq ($(HOST_OS),Darwin)
ifeq ($(ARCH),arm64)
ACCEL ?= hvf
else
ACCEL ?= tcg
endif
DISPLAY_ARGS ?= -display cocoa
else
ACCEL ?= tcg
DISPLAY_ARGS ?= -display gtk
ifneq ($(wildcard /dev/kvm),)
ifeq ($(HOST_ARCH),$(ARCH))
ACCEL := kvm
endif
endif
endif

ifeq ($(ACCEL),tcg)
CPU_MODEL ?= max
else
CPU_MODEL ?= host
endif

EFI_ARGS = -drive if=pflash,format=raw,readonly=on,file="$(EFI_CODE)" \
	   -drive if=pflash,format=raw,file="$(EFI_VARS)"
QEMU_COMMON_ARGS = -machine $(MACHINE_TYPE),accel=$(ACCEL) \
		   -cpu $(CPU_MODEL) \
		   -m $(RAM_MB) \
		   -smp $(CPUS) \
		   -drive if=virtio,file=$(DISK) \
		   $(EFI_ARGS) \
		   $(VIDEO_ARGS)
