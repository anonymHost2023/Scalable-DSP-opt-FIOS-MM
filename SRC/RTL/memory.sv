`timescale 1ns / 1ps

// This module serves as the interface between the block RAM memory components used for communication
// with the processor or other peripherals using the AXI protocol.
// It is used to load and hold operands from memory as well as the result of the FIOS computation once it is over.

module memory #(parameter int s = 16,
                localparam int PE_NB = (2*s+5+1-1)/9+1) (
    input clock_i, reset_i,    
    input start_i,

    // The global top_control FSM uses the load_store signal to indicate whether memory must perform
    // a load operands or a store result operation.
    input load_store_i,
    
    // BRAM output used to fetch data.
    input [31:0] BRAM_dout_i,
    
    // The result is stored blocks by blocks at the end of FIOS computation. res_push_i indicates a block of the result
    // must be captured.
    input [16:0] res_i,
    input res_push_i,
    
    // Operand blocks Y and n are first stored in memory before being fed to the first PE in the FIOS module using its
    // generic Y_fetch and n_fetch signals.
    input Y_fetch_i,
    input n_fetch_i,
    
    // The last Processing Element in the chain uses the shift_X signal to indicate that the X data register must be right shifted
    // and new data blocks provided to the PEs.
    input shift_X_i,
    
    // BRAM_en, BRAM_we and BRAM_addr signals are part of the Block RAM interface and are used to enable the Block RAM port,
    // to toggle read/write operations, and to address data respectively.
    output BRAM_en_o,
    output BRAM_we_o,
    // Each 32 bits wide entry in the Block RAM contains a single 17 bits block of operand or result data.
    // At least 3*s+1 32-bits memory words are required to store the n, n_prime_O, X, and Y operands (in that order).
    output [$clog2(4*s)-1:0] BRAM_addr_o,

    // The BRAM input is used to write result data into the first s memory blocks.
    output [16:0] BRAM_din_o,

    // At any point in time, PE_NB 17 bits blocks of X operand data are made available to the PEs,
    // while 17 bits blocks of n_prime_0, Y and n operand data are made available one at a time to the first
    // PE using the Y_fetch and n_fetch signals.
    output [PE_NB*17-1:0] X_o,
    output [16:0] Y_o,
    output [16:0] n_o,
    output [16:0] n_prime_0_o,
    
    // The memory_control FSM indicates the end of a load or store operation using the load_done and store_done signals.
    output load_done_o,
    output store_done_o
    
    );
    
    // The following signals declare operand shift registers and their enabled/delayed enable signals.
    wire X_reg_write;
    wire X_reg_write_dly;
    reg [s*17-1:0] X_reg;
    
    wire n_prime_0_reg_en;
    wire n_prime_0_reg_en_dly;
    reg [16:0] n_prime_0_reg;
    
    wire Y_reg_write;
    wire Y_reg_write_dly;
    reg [s*17-1:0] Y_reg;
    
    wire n_reg_write;
    wire n_reg_write_dly;
    reg [s*17-1:0] n_reg;
    
    wire res_reg_read;
    reg [s*17-1:0] res_reg;
    

    // Memory_control is the FSM in charge of loading in the internal registers of memory and storing results in the BRAM.
    memory_control #(.s(s)) memory_control_inst (
        .clock_i(clock_i), .reset_i(reset_i),
        .start_i(start_i),
        .load_store_i(load_store_i),
        .BRAM_we_o(BRAM_we_o),
        .BRAM_addr_o(BRAM_addr_o),
        .X_reg_write_o(X_reg_write),
        .n_prime_0_reg_en_o(n_prime_0_reg_en),
        .Y_reg_write_o(Y_reg_write),
        .n_reg_write_o(n_reg_write),
        .res_reg_read_o(res_reg_read),
        .load_done_o(load_done_o),
        .store_done_o(store_done_o),
        
        .BRAM_en_o(BRAM_en_o)
        
    );


    // Writes to the registers must be delayed in order to synchronize them with BRAM output data.
    delay_line #(.WIDTH(1), .DELAY(3)) X_reg_write_dly_inst (
        .clock_i(clock_i), .reset_i(reset_i), .en_i(1'b1),
        .data_i(X_reg_write),
        .data_o(X_reg_write_dly)
    );
    
    delay_line #(.WIDTH(1), .DELAY(3)) n_prime_0_reg_en_dly_inst (
        .clock_i(clock_i), .reset_i(reset_i), .en_i(1'b1),
        .data_i(n_prime_0_reg_en),
        .data_o(n_prime_0_reg_en_dly)
    );
    
    delay_line #(.WIDTH(1), .DELAY(3)) n_reg_write_dly_inst (
        .clock_i(clock_i), .reset_i(reset_i), .en_i(1'b1),
        .data_i(n_reg_write),
        .data_o(n_reg_write_dly)
    );
    
    delay_line #(.WIDTH(1), .DELAY(3)) Y_reg_write_dly_inst (
        .clock_i(clock_i), .reset_i(reset_i), .en_i(1'b1),
        .data_i(Y_reg_write),
        .data_o(Y_reg_write_dly)
    );
    
    // BRAM output is pipelined.
    reg [16:0] BRAM_dout_i_reg;
    
    always @ (posedge clock_i)
        BRAM_dout_i_reg <= BRAM_dout_i;
    
    // A 17 bits data block is appended as most significant bits of the X_reg register when X_reg_write_dly is set.
    // Otherwise it is right shifted PE_NB*17 bits when shift_X_i is set.
    always @ (posedge clock_i) begin
        if (reset_i)
            X_reg <= 0;
        else if (X_reg_write_dly)
            X_reg <= {BRAM_dout_i_reg[16:0], X_reg[s*17-1:17]};
        else if (shift_X_i)
            X_reg <= {{(PE_NB*17){1'b0}}, X_reg[s*17-1:PE_NB*17]};
        else
            X_reg <= X_reg;
    end

    always @ (posedge clock_i) begin
        if (reset_i)
            n_prime_0_reg <= 0;
        else if (n_prime_0_reg_en_dly)
            n_prime_0_reg <= BRAM_dout_i_reg[16:0];
        else
            n_prime_0_reg <= n_prime_0_reg;
    end
    
    // A 17 bits data block is appended as most significant bits of Y_reg/n_reg register when Y_reg_write_dly/n_reg_write_dly
    // is set. Otherwise they are right shifted by 17 bits if Y_fetch/n_fetch is set.
    always @ (posedge clock_i) begin
        if (reset_i)
            n_reg <= 0;
        else if (n_reg_write_dly)
            n_reg <= {BRAM_dout_i_reg[16:0], n_reg[s*17-1:17]};
        else if (n_fetch_i)
            n_reg <= {17'd0, n_reg[s*17-1:17]};
        else
            n_reg <= n_reg;
    end
    
    
    always @ (posedge clock_i) begin
        if (reset_i)
            Y_reg <= 0;
        else if (Y_reg_write_dly)
            Y_reg <= {BRAM_dout_i_reg[16:0], Y_reg[s*17-1:17]};
        else if (Y_fetch_i)
            Y_reg <= {17'd0, Y_reg[s*17-1:17]};
        else
            Y_reg <= Y_reg;
    end
    
    // The 17 least significant bits of n_prime_0_reg/n_reg/Y_reg are sent to the FIOS module as inputs.
    // The PE_NB*17 least significant bits of the X_reg register are sent to the FIOS module as inputs.
    assign X_o = X_reg[PE_NB*17-1:0];
    assign n_prime_0_o = n_prime_0_reg;
    assign n_o = n_reg[16:0];
    assign Y_o = Y_reg[16:0];
    
    // A 17 bits data block is appended as most significant bits of the res_reg when res_push_i is set.
    // Otherwise res_reg is right shifted by 17 bits if res_reg_read is set. 
    always @ (posedge clock_i) begin
        if (reset_i)
            res_reg <= 0;
        else if (res_push_i)
            res_reg <= {res_i, res_reg[s*17-1:17]};
        else if (res_reg_read)
            res_reg <= {17'd0, res_reg[s*17-1:17]};
        else
            res_reg <= res_reg;
    end
    
    // The 17 least significant bits of res_reg are sent to the Block RAM as inputs.
    assign BRAM_din_o = res_reg[16:0];
    
    
endmodule

