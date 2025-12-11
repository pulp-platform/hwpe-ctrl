#!/bin/bash
peakrdl regblock  hwpe_ctrl_regif_example.rdl -o rdl-example/ --cpuif obi-flat --default-reset arst_n --hwif-report --addr-width 32
peakrdl html      hwpe_ctrl_regif_example.rdl -o rdl-example/html/
peakrdl c-header  hwpe_ctrl_regif_example.rdl -o rdl-example/hwpe_ctrl_target.h
# PeakRDL uses unpacked structs to avoid issues at compile time, which is commendable, but incompatible with FIFOing the output of the job!
sed -i 's/typedef[[:space:]]\+struct\b/typedef struct packed/g' rdl-example/hwpe_ctrl_regif_example_pkg.sv
