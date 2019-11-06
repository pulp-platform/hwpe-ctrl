#!/usr/bin/env python
#
# uloop_run.sv
# Francesco Conti <fconti@iis.ee.ethz.ch>
#
# Copyright (C) 2017-2019 ETH Zurich, University of Bologna
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# See LICENSE.sw.txt for details.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from __future__ import print_function
from uloop_common import *

VERBOSE = False
TP = 128
fs = 3
nof = 384
nif = 384
oh = 3
ow = 3

loops_range = [
    nif/TP,
    fs,
    fs,
    nof/TP,
    ow,
    oh
]

registers = [
    0,
    0,
    0,
    0,
    nif,
    nof,
    ow*nof,
    (ow+fs-1)*nif,
    TP,
    fs*fs*nif,
    TP,
    TP + nif * (ow-1),
    nif * fs,
    0,
    0,
    TP*TP,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
]

loops_ops,code,mnem = uloop_load("code.yml")
loops = uloop_get_loops(loops_ops, loops_range)


idx  = []
for j in range(NB_LOOPS):
    idx.append(0)
state = (0,0,0,idx)
busy = False
execute = True
uloop_print_idx(state, registers, compact=True)
nb_iter = 0
for i in range(0,1000000):
    new_registers = uloop_execute(state, code, registers)
    execute,end,busy,state = uloop_state_machine(loops, state, verbose=VERBOSE)
    if execute:
        registers = new_registers
    if not busy:
        nb_iter += 1
        uloop_print_idx(state, registers, compact=True)
    if end:
        break
print("nb_iter=%d" % (nb_iter+1))
