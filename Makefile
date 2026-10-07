# SPDX-License-Identifier: GPL-2.0
# Build against a configured and built kernel tree:
#   make KDIR=/path/to/linux [ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-]
KDIR ?= /lib/modules/$(shell uname -r)/build

all modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) INSTALL_MOD_DIR=extra modules_install

.PHONY: all modules clean modules_install
