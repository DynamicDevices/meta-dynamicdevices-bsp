# Out-of-tree build for TAA5412-only TI tac5x1x (DT510 @ 0x51).
# Module name differs from in-kernel Lore snd-soc-tac5x1x (TAC5301 @ 0x50).
obj-m += snd-soc-tac5x1x-taa5412.o
snd-soc-tac5x1x-taa5412-objs := tac5x1x-i2c.o

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) clean
