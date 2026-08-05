#!/bin/bash
# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Runs the hwpe-ctrl regression suite (scripts/regression.yml) through
# scripts/bwruntests.py. bwruntests.py fans the individual test commands out
# over a multiprocessing.Pool and calls sys.exit(1) if any of them failed --
# that non-zero exit code is what fails this step in CI.
#
# Adapted from RedMulE's scripts/ci-regression.sh; the --perf flag (which
# feeds RedMulE's cycle-count benchmark tracking via scripts/perf.json) is
# dropped since hwpe-ctrl has no benchmark to publish.

Red="\e[31m"
Green="\e[32m"
EndColor="\e[0m"

if [ -z "$Target" ]; then
    echo -e "${Red}Error: no Target defined. Set the  Target variable to \"vsim\" or \"verilator\" before continue.${EndColor}"
    exit 1
fi

ScriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE_TIMEOUT=500
REGR_FILE="${REGR_FILE:-$ScriptDir/regression.yml}"
# Number of tests to run concurrently. Each entry in regression.yml only
# invokes `make hw-run` (no rebuild) against the model built once per CI
# matrix leg, so the runs are isolated and safe to parallelize. Override
# N_PROC per invocation (bounded by available cores).
N_PROC="${N_PROC:-4}"

export Target

# be verbose in ci regression
python3 "$ScriptDir/bwruntests.py" -s --yaml -t $BASE_TIMEOUT -p "$N_PROC" "$REGR_FILE"
