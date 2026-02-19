BIOS=/opt/homebrew/Cellar/qemu/10.2.1/share/qemu/edk2-aarch64-code.fd
ISO=debian-13.3.0-arm64-netinst.iso

# CDROM=debian-auto.iso
CDROM=${ISO}

all:
	@echo "make <image|install|start|build>"

build: image iso install

image:
	@echo creating image
	@rm -rf os.qcow2
	@qemu-img create -f qcow2 os.qcow2 20G

iso:
	@echo creating install iso

install:
	@echo installing os
	@qemu-system-aarch64 \
  		-machine virt,accel=hvf \
  		-cpu host \
  		-m 2048 \
  		-smp 4 \
  		-bios "${BIOS}" \
  		-drive if=virtio,file=os.qcow2 \
  		-cdrom "${CDROM}" \
  		-boot d \
		-display default \
  		-netdev user,id=net0 \
  		-device virtio-net,netdev=net0

