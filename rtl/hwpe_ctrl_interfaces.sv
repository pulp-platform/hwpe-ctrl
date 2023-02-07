/*
 * hwpe_ctrl_interfaces.sv
 * Francesco Conti <f.conti@unibo.it>
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
 */

`ifndef SYNTHESIS
timeunit 1ps;
timeprecision 1ps;
`endif

interface hwpe_ctrl_intf_periph (
  input logic clk
);

  parameter int unsigned ID_WIDTH = -1;

  logic                req;
  logic                gnt;
  logic [31:0]         add;
  logic                wen;
  logic [3:0]          be;
  logic [31:0]         data;
  logic [ID_WIDTH-1:0] id;
  logic [31:0]         r_data;
  logic                r_valid;
  logic [ID_WIDTH-1:0] r_id;

  modport master (
    output req, add, wen, be, data, id,
    input  gnt, r_data, r_valid, r_id
  );
  modport slave (
    input  req, add, wen, be, data, id,
    output gnt, r_data, r_valid, r_id
  );

`ifndef SYNTHESIS
  task write(
    input logic [31:0] w_add,
    input logic [3:0]  w_be,
    input logic [31:0] w_data,
    input time TCP,
    input time TA
  );
    #(TA);
    add = w_add;
    data = w_data;
    wen = 1'b0;
    req = 1'b1;
    be = w_be;
    id = '0;
    while (gnt != 1'b1)
      #(TCP);
    #(TCP);
    req = 1'b0;
    #(TCP-TA);
  endtask

  task read(
    input logic [31:0] r_add,
    output logic [31:0] rdata,
    input time TCP,
    input time TA
  );
    #(TA);
    add = r_add;
    req = 1'b1;
    wen = 1'b1;
    id = '0;
    while (gnt != 1'b1)
      #(TCP);
    #(TCP-TA);
    rdata = r_data;
    #(TA);
    req = 1'b0;
    #(TCP-TA);
  endtask
`endif

endinterface // hwpe_ctrl_intf_periph

interface hwpe_ctrl_intf_reqrsp (
  input logic clk
);

  parameter int unsigned AW = -1;
  parameter int unsigned DW = -1;

  // Q (request) channel
  logic [AW-1:0]   q_addr;
  logic            q_write;
  logic [DW/8-1:0] q_strb;
  logic [DW-1:0]   q_data;
  // Q (request) handshake
  logic            q_valid;
  logic            q_ready;

  // P (response) channel
  logic [DW-1:0]   p_data;
  // P (response) handshake
  logic            p_valid;
  logic            p_ready;

  modport initiator (
    output q_addr, q_write, q_strb, q_data, q_valid, p_ready,
    input  p_data, p_valid, q_ready
  );
  modport target (
    input  q_addr, q_write, q_strb, q_data, q_valid, p_ready,
    output p_data, p_valid, q_ready
  );

endinterface // hwpe_ctrl_intf_reqrsp
