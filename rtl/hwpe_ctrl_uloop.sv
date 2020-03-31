/*
 * hwpe_ctrl_uloop.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 *
 * Copyright (C) 2014-2018 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * This module implements a very simple microcode processor that can be used to
 * compute updated base indeces for the streamers.
 * It can directly operate on NB_REG registers and read NB_RO_REG other
 * ones.
 */

import hwpe_ctrl_package::*;

module hwpe_ctrl_uloop
#(
  parameter int unsigned LENGTH        = hwpe_ctrl_package::ULOOP_MAX_NB_LOOPS,
  parameter int unsigned NB_LOOPS      = hwpe_ctrl_package::ULOOP_MAX_LENGTH,
  parameter int unsigned NB_RO_REG     = hwpe_ctrl_package::ULOOP_MAX_NB_RO_REG,
  parameter int unsigned NB_REG        = hwpe_ctrl_package::ULOOP_MAX_NB_REG,
  parameter int unsigned REG_WIDTH     = hwpe_ctrl_package::ULOOP_MAX_REG_WIDTH,
  parameter int unsigned CNT_WIDTH     = hwpe_ctrl_package::ULOOP_MAX_CNT_WIDTH,
  parameter int unsigned SHADOWED      = hwpe_ctrl_package::ULOOP_DEFAULT_SHADOWED,
  parameter int unsigned DEBUG_DISPLAY = 0
)
(
  // global signals
  input  logic                                clk_i,
  input  logic                                rst_ni,
  input  logic                                test_mode_i,
  input  logic                                clear_i,
  // ctrl & flags
  input  ctrl_uloop_t                         ctrl_i,
  output flags_uloop_t                        flags_o,
  input  uloop_code_t                         uloop_code_i,
  input  logic [NB_RO_REG-1:0][REG_WIDTH-1:0] registers_read_i
);

  logic [3:0]                         curr_op,   next_op;
  logic [$clog2(LENGTH)-1:0]          curr_addr, next_addr;
  logic [$clog2(NB_LOOPS)-1:0]        curr_loop, next_loop, out_loop;
  logic [NB_LOOPS-1:0][CNT_WIDTH-1:0] curr_idx,  next_idx;

  logic [NB_REG-1:0]          [REG_WIDTH-1:0] registers, next_registers;
  logic [NB_RO_REG+NB_REG-1:0][REG_WIDTH-1:0] registers_read;

  logic [REG_WIDTH-1:0] uloop_execute_add;
  logic [REG_WIDTH-1:0] uloop_execute;

  logic busy_int, busy_sticky;
  logic done_int, done_sticky;
  logic exec_int;
  logic flags_valid;
  flags_uloop_t flags_int;

  logic enable_int;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      busy_sticky <= '0;
      done_sticky <= '0;
      flags_valid <= '0;
    end
    else if(clear_i | ctrl_i.clear) begin
      busy_sticky <= '0;
      done_sticky <= '0;
      flags_valid <= '0;
    end
    else begin
      flags_valid <= busy_sticky & ~busy_int;
      if(~busy_int)
        busy_sticky <= 1'b0;
      else if(enable_int)
        busy_sticky <= 1'b1;
      if(done_int)
        done_sticky <= 1'b1;
      else if(flags_valid)
        done_sticky <= 1'b0;
    end
  end

  assign flags_int.done = done_int | done_sticky;
  assign flags_int.valid = flags_valid;
  assign flags_int.ready = 1'b1;

`ifndef SYNTHESIS
  enum { UPDATE, ITERATE_GOTO0, ITERATE, GOTO, TERMINATE, NULL } str_enum;

  generate
    if(DEBUG_DISPLAY) begin : debug_display
      always_ff @(posedge clk_i or negedge rst_ni)
      begin
        if(rst_ni) begin
          if(enable_int) begin
            if (str_enum == UPDATE)
              $display("@%d [%d, %d, %d, %d, %d, %d]%s", curr_addr, curr_idx[5], curr_idx[4], curr_idx[3], curr_idx[2], curr_idx[1], curr_idx[0], " UPDATE CURRENT LOOP                      ");
            else if(str_enum == ITERATE_GOTO0)
              $display("@%d [%d, %d, %d, %d, %d, %d]%s", curr_addr, curr_idx[5], curr_idx[4], curr_idx[3], curr_idx[2], curr_idx[1], curr_idx[0], " ITERATE CURRENT LOOP AND GOTO LOOP 0     ");
            else if(str_enum == ITERATE)
              $display("@%d [%d, %d, %d, %d, %d, %d]%s", curr_addr, curr_idx[5], curr_idx[4], curr_idx[3], curr_idx[2], curr_idx[1], curr_idx[0], " ITERATE CURRENT LOOP                     ");
            else if(str_enum == ITERATE)
              $display("@%d [%d, %d, %d, %d, %d, %d]%s", curr_addr, curr_idx[5], curr_idx[4], curr_idx[3], curr_idx[2], curr_idx[1], curr_idx[0], " GOTO NEXT LOOP                           ");
            else if(str_enum == TERMINATE)
              $display("@%d [%d, %d, %d, %d, %d, %d]%s", curr_addr, curr_idx[5], curr_idx[4], curr_idx[3], curr_idx[2], curr_idx[1], curr_idx[0], " TERMINATE                                ");
          end
        end
      end
    end
  endgenerate
`endif

  always_comb
  begin : uloop_fetch_comb
    next_addr = curr_addr;
    next_loop = curr_loop;
    next_op   = curr_op;
    next_idx  = curr_idx;
    done_int  = 1'b0;
    busy_int  = 1'b0;
    exec_int  = 1'b0;
`ifndef SYNTHESIS
    str_enum = NULL;
`endif

    // if next operation is within the current loop, update address
    if((curr_idx[curr_loop] < uloop_code_i.range[curr_loop] - 1) && (curr_op < uloop_code_i.loops[curr_loop].nb_ops - 1)) begin
`ifndef SYNTHESIS
      str_enum = UPDATE;
`endif
      next_addr = curr_addr + 1;
      next_op   = curr_op + 1;
      busy_int  = 1'b1;
      exec_int  = 1'b1;
    end
    // if loop > 0, go to loop 0
    else if((curr_idx[curr_loop] < uloop_code_i.range[curr_loop] - 1) && (curr_loop > 0)) begin
`ifndef SYNTHESIS
      str_enum = ITERATE_GOTO0;
`endif
      next_loop = 0;
      for(int j=0; j<NB_LOOPS; j++) begin
        if(curr_loop > j)
          next_idx[j] = 0;
        else if(curr_loop == j)
          next_idx[j] = curr_idx[curr_loop] + 1;
      end
      next_addr = uloop_code_i.loops[0].uloop_addr;
      next_op   = '0;
      exec_int  = 1'b1;
    end
    // if we are still within the current loop range, go back to start loop address
    else if(curr_idx[curr_loop] < uloop_code_i.range[curr_loop] - 1) begin
`ifndef SYNTHESIS
      str_enum = ITERATE;
`endif
      next_addr = uloop_code_i.loops[curr_loop].uloop_addr;
      next_op   = '0;
      next_idx[curr_loop] = curr_idx + 1;
      exec_int  = 1'b1;
    end
    // if not, go to next loop
    else if (curr_loop < NB_LOOPS-1) begin
`ifndef SYNTHESIS
      str_enum = GOTO;
`endif
      next_loop = curr_loop + 1;
      next_addr = uloop_code_i.loops[curr_loop+1].uloop_addr;
      next_op   = '0;
    end
    // end of the loops
    else begin
`ifndef SYNTHESIS
      str_enum = NULL;
`endif
      next_loop = '0;
      next_addr = '0;
      next_op   = '0;
      next_idx  = '0;
      done_int  = 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : uloop_fetch_seq
    if(~rst_ni) begin
      curr_addr <= '0;
      curr_loop <= '0;
      curr_op   <= '0;
      curr_idx  <= '0;
    end
    else if(clear_i | ctrl_i.clear) begin
      curr_addr <= '0;
      curr_loop <= '0;
      curr_op   <= '0;
      curr_idx  <= '0;
    end
    else if(enable_int) begin
      curr_addr <= next_addr;
      curr_loop <= next_loop;
      curr_op   <= next_op;
      curr_idx  <= next_idx;
    end
  end

  assign registers_read[NB_REG-1:0] = registers;
  assign registers_read[NB_RO_REG+NB_REG-1:NB_REG] = registers_read_i;

  assign uloop_execute_add = registers_read[uloop_code_i.code[curr_addr].a] + registers_read[uloop_code_i.code[curr_addr].b];
  assign uloop_execute = (uloop_code_i.code[curr_addr].op_sel) ? uloop_execute_add : registers_read[uloop_code_i.code[curr_addr].b];

  always_comb
  begin : uloop_execute_comb
    next_registers = registers;
    if(exec_int)
      next_registers[uloop_code_i.code[curr_addr].a] = uloop_execute;
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : uloop_execute_sel
    if(~rst_ni) begin
      registers <= '0;
    end
    else if(clear_i | ctrl_i.clear) begin
      registers <= '0;
    end
    else if(enable_int) begin
      registers <= next_registers;
    end
  end

  generate

    for(genvar i=0; i<NB_REG; i++) begin : flags_reg_assign
      assign flags_int.offs[i] = registers[i];
    end
    for(genvar i=0; i<NB_LOOPS; i++) begin : flags_idx_assign
      assign flags_int.idx [i] = curr_idx[i];
    end

  endgenerate

  // save executed loop for output flags
  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni)
      out_loop <= '0;
    else if(clear_i)
      out_loop <= '0;
    else if(exec_int)
      out_loop <= curr_loop;
  end

  generate

    if(SHADOWED) begin: shadowed_gen

      flags_uloop_t shadow_flags_wr, shadow_flags_rd;
      logic out_valid;

      // when the shadow register is not valid, enable the uloop
      assign enable_int = ~shadow_flags_wr.valid & ~flags_valid & ~clear_i;

      // the shadow register is updated when flags_valid is 1'b1
      always_ff @(posedge clk_i or negedge rst_ni)
      begin
        if(~rst_ni)
          shadow_flags_wr <= '0;
        else if(clear_i | ctrl_i.enable)
          shadow_flags_wr <= '0;
        else if (flags_int.valid)
          shadow_flags_wr <= flags_int;
      end

      // the uloop replies with the already computed values as soon as asked
      always_ff @(posedge clk_i or negedge rst_ni)
      begin
        if(~rst_ni)
          out_valid <= 1'b0;
        else if(clear_i)
          out_valid <= 1'b0;
        else
          out_valid <= ctrl_i.enable;
      end

      // the read shadow flags are updated on ctrl_i enable
      always_ff @(posedge clk_i or negedge rst_ni)
      begin
        if(~rst_ni)
          shadow_flags_rd <= '0;
        else if(clear_i)
          shadow_flags_rd <= '0;
        else if(ctrl_i.enable)
          shadow_flags_rd <= shadow_flags_wr;
      end

      always_comb
      begin
        flags_o = shadow_flags_rd;
        flags_o.valid = out_valid;
        flags_o.ready = shadow_flags_wr.valid;
        flags_o.loop  = out_loop;
      end

    end // shadowed_gen
    else begin: no_shadowed_gen

      assign enable_int = ctrl_i.enable;

      always_comb
      begin
        flags_o = flags_int;
        flags_o.loop = out_loop;
      end

    end // no_shadowed_gen

  endgenerate

endmodule // hwpe_ctrl_uloop
