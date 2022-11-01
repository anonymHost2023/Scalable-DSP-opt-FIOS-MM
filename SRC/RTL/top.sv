`timescale 1ns / 1ps

// This module is a wrapper for the memory, top_control and FIOS submodules, which are linked together.

module top #(parameter s = 16,
             localparam int DSP_NB = (2*s+5+1-1)/9+1) (
    input clock_i, reset_i,

    // Start and reset signals are issued by the processor.
    input start_i,

    // The BRAM interface is connected to the memory module.
    input [31:0] BRAM_dout_i,
    
    output [31:0] BRAM_din_o,
    
    output BRAM_we_o,
    output [31:0] BRAM_addr_o,
    
    output BRAM_en_o,

    // The done_o status signal indicates to the processor that the global routine is over and that result data
    // can be read from the BRAM, at which point the design waits for reset.
    output done_o
    
    );
    
    
    wire load_done;
    wire store_done;
    wire FIOS_last;
    
    wire mem_start;
    wire load_store;
    wire FIOS_start;
    
    top_control top_control_inst (
        .clock_i(clock_i), .reset_i(reset_i),
        .start_i(start_i),
        
        .load_done_i(load_done),
        .store_done_i(store_done),
        .FIOS_last_i(FIOS_last),
        
        .mem_start_o(mem_start),
        .load_store_o(load_store),
        .FIOS_start_o(FIOS_start),
        
        .done_o(done_o)
    );

    
    wire [16:0] res;
    wire res_push;
    
    wire shift_X;
    
    wire Y_fetch;
    wire n_fetch;
    
    wire [DSP_NB*17-1:0] X;
    wire [16:0] Y;
    wire [16:0] n_prime_0;
    wire [16:0] n;
    
    wire [$clog2(4*s)-1:0] BRAM_addr;
    
    wire [16:0] BRAM_din;
    
    // BRAM address uses 32 bits. Non significant bits are set to 0.
    assign BRAM_addr_o = {{(32-$clog2(4*s)){1'b0}}, BRAM_addr};

    memory #(.s(s)) memory_inst (
        .clock_i(clock_i), .reset_i(reset_i),
        .start_i(mem_start),
        .load_store_i(load_store),
        
        .BRAM_dout_i(BRAM_dout_i),
        
        .res_i(res),
        .res_push_i(res_push),
        
        .Y_fetch_i(Y_fetch),
        .n_fetch_i(n_fetch),
        
        .shift_X_i(shift_X),
        
        .BRAM_we_o(BRAM_we_o),
        .BRAM_addr_o(BRAM_addr),
        
        .BRAM_din_o(BRAM_din),
        
        .X_o(X),
        .Y_o(Y),
        .n_o(n),
        .n_prime_0_o(n_prime_0),
        
        .load_done_o(load_done),
        .store_done_o(store_done),
        
        .BRAM_en_o(BRAM_en_o)
    );

    FIOS #(.s(s)) FIOS_inst (
        .clock_i(clock_i), .reset_i(reset_i),
        .start_i(FIOS_start),
        
        .X_i(X),
        .n_prime_0_i(n_prime_0),
        .Y_i(Y),
        .n_i(n),
        
        .n_fetch_o(n_fetch),
        .Y_fetch_o(Y_fetch),
        
        .res_push_o(res_push),
        
        .last_o(FIOS_last),
        
        .res_o(res),
        
        .shift_X_o(shift_X)        
        
    );

    // Only 17 least significant bits are written to the 32 bits wide BRAM words, remaining bits are set to 0.
    assign BRAM_din_o = {{(32-17){1'b0}}, BRAM_din};

endmodule

