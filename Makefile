all: flyanx.img loader.bin

boot.bin: ./src/boot/boot.asm
	@nasm -i./src/boot/include/ -o ./target/$@ $<

boot.o: ./src/boot/boot.asm
	nasm -f elf -o ./target/$@ $<

loader.bin: ./src/boot/loader.asm
	@nasm -o ./target/$@ $<

flyanx.img: boot.bin
	@cat ./target/$<  > ./target/$@

createFloppyDisk: boot.bin loader.bin
	@dd if=/dev/zero of=./target/0.bin bs=1M count=1
	@cat ./target/$< ./target/0.bin > ./target/flyanx.img

createFloppyDisk2:
	@dd if=./target/$< of=./target/flyanx.img bs=512 count=1 conv=notrunc

mountImg: ./target/flyanx.img
	@sudo mount -t msdos -o loop $< /media/floppyDisk/

unmountImg:
	@sudo umount /media/floppyDisk/

clean:
	@rm -rf ./target/*

run: ./target/flyanx.img
	make mountImg
	sudo cp -i ./target/loader.bin /media/floppyDisk/loader.bin
	make unmountImg
	@qemu-system-i386 -boot a -fda $<

runBochs:
	@bochs

deasmElf: ./target/boot.o
	@objdump -S $<

deasm: ./target/boot.bin
	@ndisasm $<

remake:
	@make clean
	@make createFloppyDisk
