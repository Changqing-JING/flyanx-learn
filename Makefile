all: flyanx.img

boot.bin: ./src/boot/boot.asm
	@nasm -o ./target/$@ $<

boot.o: ./src/boot/boot.asm
	nasm -f elf -o ./target/$@ $<

flyanx.img: boot.bin
	@cat ./target/$<  > ./target/$@

createFloppyDisk: boot.bin
	@dd if=/dev/zero of=./target/0.bin bs=1M count=1
	@cat ./target/$< ./target/0.bin > ./target/flyanx.img

createFloppyDisk2:
	@dd if=./target/$< of=./target/flyanx.img bs=512 count=1 conv=notrunc

mountImg: ./target/flyanx.img
	@sudo mount -t msdos -o loop $< /media/floppyDisk/

umountImg:
	@sudo umount /media/floppyDisk/

clean:
	@rm -rf ./target/*

run: flyanx.img
	@qemu-system-i386 -boot a -fda ./target/flyanx.img

runBochs:
	@bochs

deasmElf: ./target/boot.o
	@objdump -S $<

deasm: ./target/boot.bin
	@ndisasm $<

remake:
	@make clean
	@make all
