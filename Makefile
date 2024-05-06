NASM:=nasm
NASMFLAGS:=-f elf64 -g -F DWARF -Wall
SRCS:= helloworld.asm

TARGET:=helloworld

OBJS=$(SRCS:.asm=.o)

all: $(TARGET)

%.o: %.asm 
	$(NASM) $(NASMFLAGS) $< -o $@

$(TARGET): $(OBJS)
	ld -o $@ $^

clean:
	rm -f *.o
	rm -f helloworld
