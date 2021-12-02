.PHONY: build dist clean init menuconfig busybox-menuconfig linux-menuconfig rebuild-images backup-config restore-config toolchain sdk
CONF_DIR=./configuration/br-config
BR_DIR=./buildroot
BR_TGZ_VERSION=2021.08.2
BR_TGZ_SHA256="e7ae30803c51708686c4902b9caa204007d93bb1b0b2d1b3bc57ef20196bcb20"
TOOLCHAIN_NAME=arm-buildroot-linux-uclibcgnueabihf_sdk-buildroot

#
# Standard build with current config in the BR
# directory.
#
build:
	@cd $(BR_DIR); make --no-print-directory

#
# Invoke Buildroot build using the config in this
# repository. Place output image files into the
# `dist` directory here.
#
dist:
	@rm -rf ./dist
	@make -s restore-config
	@cd $(BR_DIR); make --no-print-directory -s clean
	@cd $(BR_DIR); make --no-print-directory
	@mkdir -p ./dist
	@cp -r buildroot/output/images/* ./dist/

#
# Invoke Buildroot clean target.
#
clean:
	@cd $(BR_DIR); make --no-print-directory -s clean

#
# Invoke Buildroot config in the BR directory.
#
menuconfig:
	@cd $(BR_DIR); make --no-print-directory -s menuconfig

#
# Invoke Busybox config in the BR directory.
#
busybox-menuconfig:
	@cd $(BR_DIR); make --no-print-directory -s busybox-menuconfig

#
# Invoke Kernel config in the BR directory.
#
linux-menuconfig:
	@cd $(BR_DIR); make --no-print-directory -s linux-menuconfig

#
# Invalidate installed packages, rebuild image output files.
#
rebuild-images:
	@rm -rf $(BR_DIR)/output/target
	@find $(BR_DIR)/output/ -name ".stamp_target_installed" |xargs rm -rf
	@cd $(BR_DIR); make --no-print-directory

#
# Make a snapshot of the BR config current and menuconfig
# data into this scope. Allows for better diff inspection
# and config revisioning. It's similar to 'savedefconfig'
# for all parts, except that the current menuconfig snapshots
# are also included.
#
backup-config:
	-@cp -f $(BR_DIR)/.config $(CONF_DIR)/buildroot.config
	-@cp -f $(BR_DIR)/package/busybox/busybox.config $(CONF_DIR)/busybox.config
	-@[ -f $(BR_DIR)/output/build/linux-custom/.config ] && cp -f $(BR_DIR)/output/build/linux-custom/.config $(CONF_DIR)/linux.config
	-@[ -f $(BR_DIR)/output/build/busybox-1.33.1/.config ] && cp -f $(BR_DIR)/output/build/busybox-1.33.1/.config $(CONF_DIR)/busybox.config
	-@sed -e '/^\(#\|\s*$$\)/d' $(CONF_DIR)/buildroot.config > $(CONF_DIR)/buildroot.min.config
	-@sed -e '/^\(#\|\s*$$\)/d' $(CONF_DIR)/busybox.config > $(CONF_DIR)/busybox.min.config
	-@sed -e '/^\(#\|\s*$$\)/d' $(CONF_DIR)/linux.config > $(CONF_DIR)/linux.min.config

#
# Place revisioned config files from here into the
# corresponding BR locations, including the current
# menuconfig snapshots. Quite like loading the defconfigs
# out-of-tree.
#
restore-config:
	@cp -f $(CONF_DIR)/buildroot.config $(BR_DIR)/buildroot.config
	@cp -f $(CONF_DIR)/busybox.config $(BR_DIR)/busybox.config
	@cp -f $(CONF_DIR)/linux.config $(BR_DIR)/linux.config
	@cp -f $(CONF_DIR)/buildroot.config $(BR_DIR)/.config
	@mkdir -p $(BR_DIR)/package/busybox
	@cp -f $(CONF_DIR)/busybox.config $(BR_DIR)/package/busybox/busybox.config
	@mkdir -p $(BR_DIR)/output/build/busybox-1.33.1
	@cp -f $(CONF_DIR)/busybox.config $(BR_DIR)/output/build/busybox-1.33.1/.config
	@mkdir -p $(BR_DIR)/output/build/linux-custom
	@cp -f $(CONF_DIR)/linux.config $(BR_DIR)/output/build/linux-custom/.config

#
# Phony alias for toolchain build.
#
sdk: toolchain/$(TOOLCHAIN_NAME).tar.gz

#
# Initialization, download BR, build SDK, prepare environment.
#
init: $(BR_DIR)/.extracted | sdk
	@mkdir -p .archive/download-cache
	@echo "Initializing config ..."
	@make -s restore-config
	@echo "Triggering buildroot resource downloads to get an initial cache ..."
	@cd buildroot; make --no-print-directory source
	@echo "Done. Say 'make' or 'make dist' to build. Say 'make menuconfig', 'make linux-menuconfig', 'make linux-menuconfig' to modify the system."

#
# Buildroot based own toolchain build.
# @see https://buildroot.org/downloads/manual/manual.html#_cross_compilation_toolchain
#
toolchain/$(TOOLCHAIN_NAME).tar.gz: $(BR_DIR)/.extracted
	@mkdir -p toolchain;
	@mkdir -p .archive/download-cache
	@make -s restore-config
	@cp -f $(CONF_DIR)/toolchain.config $(BR_DIR)/.config
	@echo "Downloading everything needed ('make source'). If something goes wrong the log will be printed. Grab coffee ..."
	@make -C buildroot --no-print-directory source >.archive/download-cache/downloads.log 2>&1 || cat .archive/download-cache/downloads.log
	@echo "Triggering SDK build ('make sdk') ..."
	@make -C buildroot --no-print-directory sdk
	@cp -f $(BR_DIR)/output/images/$(TOOLCHAIN_NAME).tar.gz toolchain/
	@make -s clean
	@echo "Done. The SDK build config is still active, say 'make restore-config' before building the target."

#
# Bildroot root directory (extracted from tarball).
#
$(BR_DIR)/.extracted: .archive/buildroot-$(BR_TGZ_VERSION).tar.gz
	@echo "Extracting buildroot tarball ..."
	@[ ! -d "$(BR_DIR)" ] || (echo "Error: buildroot directory exists, but not '$(BR_DIR)/.extracted'."; /bin/false)
	@tar -xzf ".archive/buildroot-$(BR_TGZ_VERSION).tar.gz"
	@mv "buildroot-$(BR_TGZ_VERSION)" "$(BR_DIR)"
	@make -s restore-config
	@touch $(BR_DIR)/.extracted

#
# BR tarball download
#
.archive/buildroot-$(BR_TGZ_VERSION).tar.gz:
	@mkdir -p .archive
	@echo "Downloading buildroot v$(BR_TGZ_VERSION) sources ..."
	@curl -s -S -o ".archive/buildroot-$(BR_TGZ_VERSION).tgz" "https://buildroot.org/downloads/buildroot-$(BR_TGZ_VERSION).tar.gz"
	@shasum -a256 .archive/buildroot-$(BR_TGZ_VERSION).tgz | sed -e 's/\s.*//' > .archive/buildroot-$(BR_TGZ_VERSION).tar.gz.sha256
	@[ -z "$(BR_TGZ_SHA256)" ] || [ "$$(cat .archive/buildroot-$(BR_TGZ_VERSION).tar.gz.sha256)" = "$(BR_TGZ_SHA256)" ] || (echo "SHA256 of the downloaded archive does not match."; /bin/false)
	@mv .archive/buildroot-$(BR_TGZ_VERSION).tgz .archive/buildroot-$(BR_TGZ_VERSION).tar.gz
