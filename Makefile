ImgMountPoint =/media/floppyDisk
IncludeFlags =-i./src/boot/include/
tb = target/boot
t = target

srcBoot = ./src/boot

$(tb):
	@mkdir $@

createDir: $(tb)

all: createDir $(tb)/boot.bin $(tb)/loader.bin

$(tb)/boot.bin: $(srcBoot)/boot.asm
	@nasm $(IncludeFlags) -o $@ $<

$(tb)/loader.bin: $(srcBoot)/loader.asm
	@nasm $(IncludeFlags) -o $@ $<

image: all
	@dd if=/dev/zero of=$(tb)/0.bin bs=1M count=1
	@cat $(tb)/boot.bin $(tb)/0.bin > $(t)/flyanx.img
	@make mountImg
	@sudo cp -f -i $(tb)/loader.bin $(ImgMountPoint)/loader.bin
	@make unmountImg

mountImg: $(t)/flyanx.img
	@sudo mount -t msdos -o loop $< $(ImgMountPoint)/

unmountImg:
	@sudo umount $(ImgMountPoint)/

clean:
	@rm -rf $(t)/*

run: $(t)/flyanx.img
	@qemu-system-i386 -boot a -fda $<

runBochs:
	@bochs

deasm: $(tb)/boot.bin
	@ndisasm $<

remake:
	@make clean
	@make image
