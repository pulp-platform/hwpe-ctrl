# Copyright 2026 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Top-level Makefile

# Paths to folders
RootDir    := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
TargetDir  := $(RootDir)target
SimDir     := $(TargetDir)/sim

Bender ?= bender

target ?= verilator
TargetPath := $(SimDir)/$(target)

# Included makefrags
include $(TargetPath)/$(target).mk
include bender_common.mk
include bender_sim.mk

# Useful Parameters
gui ?= 0

SHELL := /bin/bash

# Regenerate the example register interface (rtl/rdl-example) from the
# PeakRDL source (rtl/hwpe_ctrl_regif_example.rdl).
.PHONY: regif regif-clean
regif:
	cd rtl && ./rdl.sh

regif-clean:
	rm -rf rtl/rdl-example

clean-all:
	rm -rf $(RootDir).bender

# Install tools
VendorDir  ?= $(RootDir)vendor
InstallDir ?= $(VendorDir)/install
# Bender (installed from prebuilt release binaries, no Rust toolchain needed)
BenderVersion ?= 0.32.1
CargoInstallDir := $(InstallDir)/cargo

bender: $(CargoInstallDir)/bin/bender

$(CargoInstallDir)/bin/bender:
	mkdir -p $(InstallDir)
	curl --proto '=https' --tlsv1.2 -sSfL https://github.com/pulp-platform/bender/releases/download/v$(BenderVersion)/bender-installer.sh > $(InstallDir)/bender-installer.sh
	BENDER_INSTALL_DIR=$(CargoInstallDir) BENDER_NO_MODIFY_PATH=1 BENDER_DISABLE_UPDATE=1 \
		sh $(InstallDir)/bender-installer.sh
	rm -f $(InstallDir)/bender-installer.sh
