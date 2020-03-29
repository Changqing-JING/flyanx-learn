all: flyanx.img

boot.bin: ./src/boot/boot.asm
	@nasm -o ./target/$@ $<

boot.o: ./src/boot/boot.asm
	nasm -f elf -o ./target/$@ $<

flyanx.img: boot.bin
	@cat ./target/$<  > ./target/$@


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
