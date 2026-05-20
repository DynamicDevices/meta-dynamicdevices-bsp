# Out-of-tree build for Yocto (meta-dynamicdevices-bsp). TI tree ships src/tac5x1x-i2c.c only.
obj-m += snd-soc-tac5x1x.o
snd-soc-tac5x1x-objs := tac5x1x-i2c.o

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) clean
