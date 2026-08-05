# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Makefragment for Verilator simulation.

# Taken from PATH (system package, environment module, ...); override with
# `make ... Verilator=/path/to/verilator`.
Verilator ?= verilator
# Overridable per-build: `make ... Module=hwpe_ctrl_uloop_tb`.
Module ?= hwpe_ctrl_target_tb
# Per-module object dir, since a single shared obj_dir would collide across
# the different tops built from MODULES below.
ObjDirName := obj_dir_$(Module)
Vmodule := V$(Module)
VerilatorDir := $(SimDir)/$(target)
VerilatorAbsObjDir := $(VerilatorDir)/$(ObjDirName)
VerilatorCompileScript := $(VerilatorDir)/compile.$(target).tcl
VerilatorWaves := $(VerilatorDir)/$(Module).vcd
# Number of contexts instantiated in the testbench. Only
# hwpe_ctrl_target_tb_wrap exposes an NB_CONTEXT parameter; see the
# conditional -G below.
NbContext ?= 2
# Selects which test the testbench runs; see target/sim/src for the list.
TEST ?= reg_access
# Parallelism for hw-build. With --binary this covers both verilation and the
# C++ compile of the model.
VerilatorJobs ?= 4

# All tops built from the shared hwpe_ctrl_test bender target (see
# Bender.yml); used by hw-build-all and hw-clean to iterate over every
# per-module object dir.
MODULES := hwpe_ctrl_target_tb hwpe_ctrl_uloop_tb hwpe_ctrl_partial_mult_tb hwpe_ctrl_seq_mult_tb

VerilatorFlags = --trace --timing --bbox-unsup \
	-Wall -Wno-fatal --Wno-lint --Wno-UNOPTFLAT --Wno-MODDUP -Wno-BLKANDNBLK -Wno-ENUMVALUE \
	-j $(VerilatorJobs) \
	--x-assign unique --x-initial unique --top-module $(Module)_wrap --Mdir $(VerilatorAbsObjDir) \
	$(if $(filter hwpe_ctrl_target_tb,$(Module)),-GNB_CONTEXT=$(NbContext),)

hw-clean:
	rm -rf $(foreach m,$(MODULES),$(VerilatorDir)/obj_dir_$(m)) $(VerilatorCompileScript) $(VerilatorDir)/transcript* $(VerilatorDir)/*.vcd

hw-script: regif
	$(Bender) checkout
	$(Bender) script $(target)     \
	$(common_targs) $(common_defs) \
	$(sim_targs)                   \
	> $(VerilatorCompileScript)

# Actual verilator invocation, factored out of hw-build so hw-build-all can
# reuse it per-module without re-running hw-script (regif + bender
# checkout + bender script) once per module.
hw-build-one:
	OBJCACHE=ccache $(Verilator) $(VerilatorFlags) --binary -sv -cc -f $(VerilatorCompileScript)

hw-build: hw-script hw-build-one

# Builds every top in MODULES against a single, shared hw-script compile
# file list (bender emits one flat file list regardless of Module, so
# there is no need to regenerate it per module). Fails (non-zero exit) if
# any single module build fails, without skipping the rest -- so CI sees
# every broken top in one run instead of stopping at the first.
hw-build-all: hw-script
	@status=0; \
	for m in $(MODULES); do \
		echo "==> Building $$m"; \
		$(MAKE) --no-print-directory hw-build-one target=$(target) Module=$$m NbContext=$(NbContext) VerilatorJobs=$(VerilatorJobs) || status=1; \
	done; \
	exit $$status

# Fast syntax/elaboration check only, without running the C++/binary build.
# Useful to fail fast while sibling work packages are still landing sources.
hw-lint: hw-script
	$(Verilator) $(VerilatorFlags) --lint-only -sv -cc -f $(VerilatorCompileScript)

# Intentionally does NOT depend on hw-build: CI builds the simulation binary
# once per matrix leg and then invokes hw-run multiple times with different
# TEST= values against that same binary.
hw-run:
	$(VerilatorAbsObjDir)/$(Vmodule)_wrap \
	+TEST=$(TEST) \
	$(if $(filter 1,$(gui)),,+NOTRACE)

hw-all: hw-clean hw-build hw-run
