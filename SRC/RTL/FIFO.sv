`timescale 1ns / 1ps

// This module is a wrapper for the xilinx parametrized macro instance of a synchronous FIFO.
// FIFOs are used in the design to circulate operands between different PEs.

module FIFO #(parameter WIDTH = 17,
                        DEPTH = 16) (
    input clock_i, reset_i,
    input write_en_i,
    input read_en_i,
    
    input [WIDTH-1:0] data_i,
    
    output [WIDTH-1:0] data_o

    );
    
    
   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(0),     // DECIMAL
      .FIFO_WRITE_DEPTH(DEPTH),   // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .READ_DATA_WIDTH(WIDTH),      // DECIMAL
      .READ_MODE("fwft"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0000"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(WIDTH)     // DECIMAL
   )
   xpm_fifo_sync_inst (

      .dout(data_o),

      .din(data_i),

      .rd_en(read_en_i),

      .rst(reset_i),

      .wr_clk(clock_i),

      .wr_en(write_en_i)

   );

    
    
endmodule
