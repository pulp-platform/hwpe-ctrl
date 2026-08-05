# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Makefragment for Verilator simulation.

# Taken from PATH (system package, environment module, ...); override with
# `make ... Verilator=/path/to/verilator`.
Verilator ?= verilator
Module := hwpe_ctrl_target_tb
ObjDirName := obj_dir
Vmodule := V$(Module)
VerilatorDir := $(SimDir)/$(target)
VerilatorAbsObjDir := $(VerilatorDir)/$(ObjDirName)
VerilatorCompileScript := $(VerilatorDir)/compile.$(target).tcl
VerilatorWaves := $(VerilatorDir)/$(Module).vcd
# Number of contexts instantiated in the testbench.
NbContext ?= 2
# Selects which test the testbench runs; see target/sim/src for the list.
TEST ?= reg_access
# Parallelism for hw-build. With --binary this covers both verilation and the
# C++ compile of the model.
VerilatorJobs ?= 4

VerilatorFlags = --trace --timing --bbox-unsup \
	-Wall -Wno-fatal --Wno-lint --Wno-UNOPTFLAT --Wno-MODDUP -Wno-BLKANDNBLK -Wno-ENUMVALUE \
	-j $(VerilatorJobs) \
	--x-assign unique --x-initial unique --top-module $(Module)_wrap --Mdir $(VerilatorAbsObjDir) \
	-GNB_CONTEXT=$(NbContext)

hw-clean:
	rm -rf $(VerilatorAbsObjDir) $(VerilatorCompileScript) $(VerilatorDir)/transcript* $(VerilatorWaves)

hw-script: regif
	$(Bender) checkout
	$(Bender) script $(target)     \
	$(common_targs) $(common_defs) \
	$(sim_targs)                   \
	> $(VerilatorCompileScript)

hw-build: hw-script
	OBJCACHE=ccache $(Verilator) $(VerilatorFlags) --binary -sv -cc -f $(VerilatorCompileScript)

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
