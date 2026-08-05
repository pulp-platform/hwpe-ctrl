#!/bin/bash
# peakrdl regblock does not create its output directory on its own (unlike
# the html/c-header subcommands), so it must exist beforehand.
mkdir -p rdl-example/
peakrdl regblock  hwpe_ctrl_regif_example.rdl -o rdl-example/ --cpuif passthrough --default-reset arst_n --hwif-report --addr-width 32
peakrdl html      hwpe_ctrl_regif_example.rdl -o rdl-example/html/
peakrdl c-header  hwpe_ctrl_regif_example.rdl -o rdl-example/hwpe_ctrl_target.h
# PeakRDL uses unpacked structs to avoid issues at compile time, which is commendable, but incompatible with FIFOing the output of the job! (use portable sed syntax that works on both Linux and macOS)
sed -E 's/typedef[[:space:]]+struct([[:space:]])/typedef struct packed\1/g' rdl-example/hwpe_ctrl_regif_example_pkg.sv > rdl-example/hwpe_ctrl_regif_example_pkg.sv.tmp && mv rdl-example/hwpe_ctrl_regif_example_pkg.sv.tmp rdl-example/hwpe_ctrl_regif_example_pkg.sv

# PeakRDL does not emit a license header; prepend the repository's SPDX header to the generated SystemVerilog.
HEADER='// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51'
for f in rdl-example/hwpe_ctrl_regif_example.sv rdl-example/hwpe_ctrl_regif_example_pkg.sv; do
  printf '%s\n' "$HEADER" | cat - "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
