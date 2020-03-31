ImgMountPoint =/media/floppyDisk
IncludeFlags =-i./src/boot/include/
tb = target/boot
t = target

srcBoot = ./src/boot
FD = flyanx.img
$(tb):
	@mkdir $@

createDir: $(tb)

all: createDir $(tb)/boot.bin $(tb)/loader.bin

$(tb)/boot.bin: $(srcBoot)/boot.asm
	@nasm $(IncludeFlags) -o $@ $<

$(tb)/loader.bin: $(srcBoot)/loader.asm
	@nasm $(IncludeFlags) -o $@ $<

image: all $(FD)
	@dd if=$(tb)/boot.bin of=$(t)/$(FD) bs=512 count=1 conv=notrunc
	@make mountImg
	@sudo cp -f -i $(tb)/loader.bin $(ImgMountPoint)/loader.bin
	@make unmountImg

$(FD):
	@dd if=/dev/zero of=$(t)/$(FD) bs=512 count=2880

mountImg: $(t)/$(FD)
	@sudo mount -t msdos -o loop $< $(ImgMountPoint)/

unmountImg:
	@sudo umount $(ImgMountPoint)/

clean:
	@rm -rf $(t)/*

run: $(t)/$(FD)
	@qemu-system-i386 -boot a -fda $<

runBochs:
	@bochs

deasm: $(tb)/boot.bin
	@ndisasm $<

remake:
	@make clean
	@make image
