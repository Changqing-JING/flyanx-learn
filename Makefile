all: flyanx.img

boot.bin: ./src/boot/boot.asm
	@nasm -o ./target/$@ $<



flyanx.img: boot.bin
	@cat ./target/boot.bin  > ./target/$@


clean:
	@rm -rf ./target/*

run: flyanx.img
	qemu-system-i386 -boot a -fda ./target/flyanx.img

runBochs:
	bochs

remake:
	@make clean
	@make all
