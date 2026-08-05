# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Makefragment holding common bender flags shared across simulation and
# (future) synthesis flows. hwpe-ctrl has no core-specific configuration
# (unlike e.g. RedMulE, which uses this file to select cv32e40p/cv32e40x
# flags), so common_targs/common_defs are intentionally left empty here.
# The file is kept as a parity placeholder so downstream flows can simply
# append to common_targs/common_defs without needing to guard the include.

common_targs +=
common_defs  +=
