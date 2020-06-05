ImgMountPoint =/media/floppy
IncludeFlags =-i./src/boot/include/
tb = target/boot
tk = target/kernel
tl = target/lib
tstdio = target/lib/stdio
i386Objs = $(tl)/i386
t = target
tansi = target/lib/ansi
includePath = ./include
kernelIncludePath = ./src/kernel/include/
includeASMLib = -i./src/lib/ansi/

srcBoot = ./src/boot
srcKernel = ./src/kernel
srcAnsi = ./src/lib/ansi
srcLib = ./src/lib
FD = flyanx.img

.PHONY=clean run runBochs

$(tb):
	@mkdir -p $@

$(tk):
	@mkdir -p $@

$(tansi):
	@mkdir -p $@

$(tl):
	@mkdir -p $@

$(tstdio):
	@mkdir -p $@

$(i386Objs):
	@mkdir -p $@	

createDir: $(tb) $(tk) $(tansi) $(tl) $(tstdio) $(i386Objs)

all: createDir $(tb)/boot.bin $(tb)/loader.bin $(tk)/kernel.bin

$(tb)/boot.bin: $(srcBoot)/boot.asm
	@nasm $(IncludeFlags) -o $@ $<

$(tb)/loader.bin: $(srcBoot)/loader.asm
	@nasm $(IncludeFlags) $(includeASMLib) -o $@ $<

$(tk)/kernel.o: $(srcKernel)/kernel.asm
	@nasm -i$(kernelIncludePath) -f elf -o $@ $<

$(tansi)/string.o: $(srcAnsi)/string.asm
	@nasm $(includeASMLib) -f elf -o $@ $<

$(tk)/kernel_386lib.o: $(srcKernel)/kernel_386lib.asm
	@nasm -i$(kernelIncludePath) $(includeASMLib) -f elf -o $@ $<

$(i386Objs)/ipc_msg.o: $(srcLib)/i386/ipc/ipc_msg.asm
	@nasm -i$(kernelIncludePath) $(includeASMLib) -f elf -o $@ $<

$(tk)/main.o: $(srcKernel)/main.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath)  -c -o $@ $<


$(tk)/start.o: $(srcKernel)/start.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/table.o: $(srcKernel)/table.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/protect.o: $(srcKernel)/protect.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/exception.o: $(srcKernel)/exception.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/process.o: $(srcKernel)/process.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/printk.o: $(srcKernel)/printk.c
	@gcc -m32 -I$(srcKernel)/include -fno-stack-protector -c -o $@ $<

$(tk)/clock.o: $(srcKernel)/clock.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -fno-stack-protector -c -o $@ $<

$(tk)/i8259.o: $(srcKernel)/i8259.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/ipc_msg.o: $(srcKernel)/ipc_msg.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -fno-stack-protector -c -o $@ $<

$(tk)/misc.o: $(srcKernel)/misc.c
	@gcc -m32 -fno-stack-protector -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tk)/dump.o: $(srcKernel)/dump.c
	@gcc -m32 -I$(includePath) -I$(kernelIncludePath) -c -o $@ $<

$(tstdio)/sprintf.o: $(srcLib)/stdio/sprintf.c
	@gcc -m32 -fno-stack-protector -I$(includePath) -c -o $@ $<

$(tstdio)/vsprintf.o: $(srcLib)/stdio/vsprintf.c
	@gcc -m32 -fno-stack-protector -I$(includePath) -c -o $@ $<

$(tk)/kernel.bin: $(tk)/kernel.o $(tk)/kernel_386lib.o $(tk)/main.o $(tk)/start.o $(tk)/protect.o $(tk)/table.o $(tk)/exception.o $(tansi)/string.o $(tk)/misc.o $(tk)/i8259.o $(tk)/clock.o $(tstdio)/sprintf.o $(tstdio)/vsprintf.o $(tk)/printk.o $(tk)/process.o $(tk)/ipc_msg.o $(i386Objs)/ipc_msg.o $(tk)/dump.o
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
