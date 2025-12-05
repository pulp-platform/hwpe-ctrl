#!/bin/bash
peakrdl regblock  hwpe_ctrl_regif_example.rdl -o rdl-example/ --cpuif obi-flat --default-reset arst_n --hwif-report
peakrdl html      hwpe_ctrl_regif_example.rdl -o rdl-example/html/
peakrdl c-header  hwpe_ctrl_regif_example.rdl -o rdl-example/hwpe_ctrl_target.h

