ImgMountPoint =/media/floppyDisk
IncludeFlags =-i./src/boot/include/
tb = target/boot
tk = target/kernel
t = target

srcBoot = ./src/boot
srcKernel = ./src/kernel
FD = flyanx.img

.PHONY=clean run runBochs

$(tb):
	@mkdir $@

$(tk):
	@mkdir $@

createDir: $(tb) $(tk) 

all: createDir $(tb)/boot.bin $(tb)/loader.bin $(tk)/kernel.bin

$(tb)/boot.bin: $(srcBoot)/boot.asm
	@nasm $(IncludeFlags) -o $@ $<

$(tb)/loader.bin: $(srcBoot)/loader.asm
	@nasm $(IncludeFlags) -o $@ $<

$(tk)/kernel.o: $(srcKernel)/kernel.asm
	@nasm -f elf -o $@ $<

$(tk)/kernel_386lib.o: $(srcKernel)/kernel_386lib.asm
	@nasm -f elf -o $@ $<

$(tk)/main.o: $(srcKernel)/main.c
	@gcc -m32 -I./include -c -o $@ $<

$(tk)/kernel.bin: $(tk)/kernel.o $(tk)/kernel_386lib.o $(tk)/main.o
	@ld -m elf_i386 -N -e _start -Ttext 0x1000 -o $@ $^


image: all $(FD)
	@dd if=$(tb)/boot.bin of=$(t)/$(FD) bs=512 count=1 conv=notrunc
	@make mountImg
	@sudo cp -f -i $(tb)/loader.bin $(ImgMountPoint)/loader.bin
	@sudo cp -f -i $(tk)/kernel.bin $(ImgMountPoint)/kernel.bin
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
	@qemu-system-i386 -m 256 -boot a -fda $<

runBochs:
	@bochs

deasm: $(tb)/boot.bin
	@ndisasm $<

remake:
	@make clean
	@make image
