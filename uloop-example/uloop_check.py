#!/usr/bin/env python
#
# uloop_check.sv
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

# high-level loop
def iterate_hl_loop(TP, oh, ow, nof, nif, fs):
    y_idx = 0
    W_idx = 0
    x_idx = 0
    curr_idx = (0, 0, 0, 0, 0, 0)
    for i in range(0, oh):
        for j in range(0, ow):
            for k_out_major in range(0, nof/TP):
                for u_i in range(0, fs):
                    for u_j in range(0, fs):
                        for k_in_major in range(0, nif/TP):
                            k_out = k_out_major*TP
                            k_in = k_in_major*TP
                            y_idx = i*nof*ow + j*nof + k_out                           # HWC layout
                            W_idx = (k_out/TP)*nif*fs*fs + u_i*nif*fs + u_j*nif + k_in # CoHWCi layoyt
                            x_idx = (i+u_i)*nif*(ow+fs-1) + (j+u_j)*nif + k_in         # HWC layout
                            curr_idx = i, j, k_out_major, u_i, u_j, k_in_major
                            yield W_idx, x_idx, y_idx, curr_idx

VERBOSE = True

def uloop_check(TP, oh, ow, nof, nif, fs, verbose=VERBOSE):

    print("> Config TP=%d, oh=%d, ow=%d, nof=%d, nif=%d, fs=%d" % (TP, oh, ow, nof, nif, fs))

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

    err = 0
    idx  = []
    for j in range(NB_LOOPS):
        idx.append(0)
    state = (0,0,0,idx)
    busy = False
    execute = True
    # uloop_print_idx(state, registers)
    hidx = 0, 0, 0, 0, 0, 0
    hl_loop = iterate_hl_loop(TP, oh, ow, nof, nif, fs)
    hW, hx, hy, hidx = hl_loop.next()
    for i in range(0,1000000):
        new_registers = uloop_execute(state, code, registers)
        execute,end,busy,state = uloop_state_machine(loops, state, verbose=verbose)
        if execute:
            registers = new_registers
        if not busy:
            try:
                hW, hx, hy, hidx = hW, hx, hy, hidx = hl_loop.next()
            except StopIteration:
                pass
            if verbose:
                uloop_print_idx(state, registers)
            uW, ux, uy = registers[0:3]
            if (hW != uW or hx != ux or hy != uy):
                if verbose:
                    print("  ERROR!!!")
                    print("  High-level: W=%d x=%d y=%d" % (hW, hx, hy))
                    print("  uLoop:      W=%d x=%d y=%d" % (uW, ux, uy))
                err += 1
        if end:
            break

    print(err, " errors", "!!!" if err > 0 else "")
    return err

for oh in (1,2,3,):
    for ow in (1,2,3,):
        for fs in (1,2,3,4,5):
            for nif in range(128, 1024+128, 128):
                for nof in range(128, 1024+128, 128):
                    err = uloop_check(
                        TP = 128,
                        fs = fs,
                        nof = nof,
                        nif = nif,
                        oh = oh,
                        ow = ow,
                        verbose = False
                    )
                    if err>0:
                        break
                if err>0:
                    break
            if err>0:
                break
        if err>0:
            break
    if err>0:
        break
if err>0:
    uloop_check(
        TP = 128,
        fs = fs,
        nof = nof,
        nif = nif,
        oh = oh,
        ow = ow,
        verbose = True
    )
