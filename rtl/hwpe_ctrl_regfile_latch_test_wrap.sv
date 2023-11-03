/* 
 * hwpe_ctrl_regfile_latch.sv
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
 */

module hwpe_ctrl_regfile_latch_test_wrap
#(
   parameter  int unsigned REGFILE_SCM = 1,
   parameter  int unsigned ADDR_WIDTH = 5,
   parameter  int unsigned DATA_WIDTH = 32,
   localparam int unsigned NUM_BYTE   = DATA_WIDTH/8
)
(
   input  logic                                     clk,
   input  logic                                     rst_n,
   input  logic                                     clear,

   // Read port
   input  logic                                     ReadEnable,
   input  logic [ADDR_WIDTH-1:0]                    ReadAddr,
   output logic [DATA_WIDTH-1:0]                    ReadData,

   // Write port
   input  logic                                     WriteEnable,
   input  logic [ADDR_WIDTH-1:0]                    WriteAddr,
   input  logic [NUM_BYTE-1:0][7:0]                 WriteData,
   input  logic [NUM_BYTE-1:0]                      WriteBE,

   // Memory content (false paths!)
   output logic [2**ADDR_WIDTH-1:0][DATA_WIDTH-1:0] MemContent,

   // BIST ENABLE
   input  logic                                     BIST,
   // BIST ports
   input  logic                                     CSN_T,
   input  logic                                     WEN_T,
   input  logic [ADDR_WIDTH-1:0]                    A_T,
   input  logic [DATA_WIDTH-1:0]                    D_T,
   input  logic [NUM_BYTE-1:0]                      BE_T,
   output logic [DATA_WIDTH-1:0]                    Q_T
);

   logic                  ReadEnable_muxed;
   logic [ADDR_WIDTH-1:0] ReadAddr_muxed;

   logic                  WriteEnable_muxed;
   logic [ADDR_WIDTH-1:0] WriteAddr_muxed;
   logic [DATA_WIDTH-1:0] WriteData_muxed;
   logic [NUM_BYTE-1:0]   WriteBE_muxed;

   always_comb
   begin
      if(BIST)
      begin
         ReadEnable_muxed  = (( CSN_T == 1'b0 ) && ( WEN_T == 1'b1));
         ReadAddr_muxed    = A_T;

         WriteEnable_muxed = (( CSN_T == 1'b0 ) && ( WEN_T == 1'b0));
         WriteAddr_muxed   = A_T;
         WriteData_muxed   = D_T;
         WriteBE_muxed     = BE_T;
      end
      else
      begin
         ReadEnable_muxed  = ReadEnable;
         ReadAddr_muxed    = ReadAddr;

         WriteEnable_muxed = WriteEnable;
         WriteAddr_muxed   = WriteAddr;
         WriteData_muxed   = WriteData;
         WriteBE_muxed     = WriteBE;
      end
   end

   assign Q_T = ReadData;

   if (REGFILE_SCM == 1) begin : gen_scm_regfile
     hwpe_ctrl_regfile_latch #(
        .ADDR_WIDTH ( ADDR_WIDTH ),
        .DATA_WIDTH ( DATA_WIDTH ),
        .NUM_BYTE   ( NUM_BYTE   )
     ) hwpe_ctrl_regfile_latch_i (
        .clk         ( clk               ),
        .rst_n       ( rst_n             ),
        .clear       ( clear             ),
        .ReadEnable  ( ReadEnable_muxed  ),
        .ReadAddr    ( ReadAddr_muxed    ),
        .ReadData    ( ReadData          ),
        .WriteEnable ( WriteEnable_muxed ),
        .WriteAddr   ( WriteAddr_muxed   ),
        .WriteData   ( WriteData_muxed   ),
        .WriteBE     ( WriteBE_muxed     ),
        .MemContent  ( MemContent        )
     );
   end else begin : gen_ff_regfile
     hwpe_ctrl_regfile_ff #(
        .AddrWidth ( ADDR_WIDTH ),
        .DataWidth ( DATA_WIDTH )
     ) hwpe_ctrl_regfile_ff_i (
        .clk_i         ( clk               ),
        .rst_ni        ( rst_n             ),
        .clear_i       ( clear             ),
        .ReadEnable_i  ( ReadEnable_muxed  ),
        .ReadAddr_i    ( ReadAddr_muxed    ),
        .ReadData_o    ( ReadData          ),
        .WriteEnable_i ( WriteEnable_muxed ),
        .WriteAddr_i   ( WriteAddr_muxed   ),
        .WriteData_i   ( WriteData_muxed   ),
        .WriteBE_i     ( WriteBE_muxed     ),
        .MemContent_o  ( MemContent        )
     );
   end

endmodule // hwpe_ctrl_regfile_latch
