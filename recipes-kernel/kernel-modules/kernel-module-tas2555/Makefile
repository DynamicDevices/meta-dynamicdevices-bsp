ifneq ($(KERNELRELEASE),)
obj-m += snd-soc-tas2555.o
snd-soc-tas2555-y := tas2555-regmap.o tas2555-core.o tas2555-codec.o
ccflags-y += -DCONFIG_TAS2555_REGMAP -DCONFIG_TAS2555_CODEC -DENABLE_GPIO_RESET
else
KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) modules

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) clean
endif
