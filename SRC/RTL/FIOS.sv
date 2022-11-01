`timescale 1ns / 1ps

// This module contains and links together all the PEs
// required for the FIOS computation.

module FIOS #(//Number of 17 bits blocks required to slice operands
              parameter int s = 16,
              // Number PE for folded FIOS implementation.
              localparam int PE_NB = (2*s+5-1)/9+1,
              // Index of the last PE which will feed the FIOS result to the memory module.
              localparam LAST_PE_INDEX = ((s % PE_NB) == 0) ? PE_NB-1 : (s % PE_NB)-1) (
        input clock_i, reset_i,

        // FIOS start signal controlled by top_control module.
        input start_i,

        // The memory module feds to the FIOS module the first PE_NB blocks of X_i data.
        // Once all PEs have captured a block of X_i, it is right shifted to make new data blocks available.
        input [PE_NB*17-1:0] X_i,

        // n_prime_0_i is constant during FIOS computation and is circulated between the PEs.
        input [16:0] n_prime_0_i,

        // Y_i and n_i input operands are first stored in memory and later circulated between PEs.
        input [16:0] Y_i,
        input [16:0] n_i,
        
        // The first PE in the chain initially fetchese Y_i and n_i operands using these signals.
        output n_fetch_o,
        output Y_fetch_o,
        
        // The PE of index LAST_PE_INDEX provides the result blocks of the complete FIOS computation to the memory module.
        // It also indicates termination of the FIOS computation.
        output [16:0] res_o,
        output res_push_o,
        output reg last_o,

        // The last PE in the chain indicates that all PEs have captured a block of X_i data and that it must be right shifted.
        output shift_X_o
    );

    // The following signals connect PEs together.
    // if signal describes a PE input, signal[j] is an input of PE j and output of PE j-1.
    // if signal describes a PE output, signal[j] is an output of PE j and input of PE j+1.
    wire start [0:PE_NB];
    
    wire [0:16] n_prime_0 [0:PE_NB];
    wire [0:16] Y [0:PE_NB];
    wire [0:16] n [0:PE_NB];
    
    wire [0:16] P [0:PE_NB];
    wire [0:16] P_dly [0:PE_NB];
    
    wire n_fetch [0:PE_NB];
    wire Y_fetch [0:PE_NB];

    // All but one of these wires are dummy wires.
    wire shift_X[0:PE_NB-1];    
    wire res_push [0:PE_NB-1];
    wire last [0:PE_NB-1];
    
    // A counter is used to count the number of X data right shift that occured and determine 
    // when the LAST_PE_INDEX PE last_o signal indicates the termination of the FIOS computation
    reg [$clog2(s/PE_NB):0] shift_X_count;

    // The first PE in the chain starts when instructed to do so by the top_control FSM or by the
    // last PE in the chain when data loops back around.    
    assign start[0] = start_i | start[PE_NB];
    
    // The first PE in the chain takes as input the Y_i and n_i operands from memory during its first execution
    // and uses the Y and n operand blocks from the last PE in the chain during subsequent executions.
    assign n_prime_0[0] = n_prime_0_i;
    assign Y[0] = (shift_X_count == 0) ? Y_i : Y[PE_NB];
    assign n[0] = (shift_X_count == 0) ? n_i : n[PE_NB];

    // Output data is looped back from the last PE in the chain to the first PE.    
    assign P[0] = P[PE_NB];
    assign P_dly[0] = P_dly[PE_NB];

    genvar i;
    
    for(i = 0; i < PE_NB;i++) begin
    
        PE #(.s(s)) PE_inst (
            .clock_i(clock_i),
            .reset_i(reset_i),
            
            .start_i(start[i]),
            
            .n_fetch_i(n_fetch[i+1]),
            .Y_fetch_i(Y_fetch[i+1]),
            
            .X_i(X_i[i*17 +: 17]),
            .n_prime_0_i(n_prime_0[i]),
            .Y_i(Y[i]),
            .n_i(n[i]),
            
            .P_prev_i(P[i]),
            .P_prev_dly_i(P_dly[i]),
            
            .n_prime_0_o(n_prime_0[i+1]),
            .Y_o(Y[i+1]),
            .n_o(n[i+1]),
            
            .P_o(P[i+1]),
            .P_dly_o(P_dly[i+1]),
            
            .n_fetch_o(n_fetch[i]),
            .Y_fetch_o(Y_fetch[i]),
            .res_push_o(res_push[i]),
            
            .shift_X_o(shift_X[i]),
            .next_start_o(start[i+1]),
            .last_o(last[i])
        );
    end
    
    // The last PE in the chain increments the shift_X counter
    always @ (posedge clock_i) begin
        if (reset_i)
            shift_X_count <= 0;
        else if (shift_X[PE_NB-1])
            shift_X_count <= shift_X_count+1;
        else
            shift_X_count <= shift_X_count;
    end
    
    // The first PE in the chain fetches the n and Y operand blocks from memory.
    assign n_fetch_o = n_fetch[0];
    assign Y_fetch_o = Y_fetch[0];

    // The last PE in the chain fetches the n and Y operand blocks from the first PE in the chain.
    assign n_fetch[PE_NB] = n_fetch[0];
    assign Y_fetch[PE_NB] = Y_fetch[0];
    
    // A status flag is raised when the module is running the last "loop"
    // and is processing the last blocks of X data.
    // the result output blocks of the last PE to run are only captured during this last loop.
    reg last_loop_reg;
    
    always @ (posedge clock_i) begin
        if (reset_i)
            last_loop_reg <= 0;
        // If running the last loop and last PE has just been started, set last_loop_reg to 1.
        else if (shift_X_count == s/PE_NB & ~last_loop_reg)
            last_loop_reg <= start[LAST_PE_INDEX];
        else
            last_loop_reg <= last_loop_reg;
    end
    
    // the last_o signal from the last running PE is registered
    // and used to indicate the last result push to be performed.
    reg last_dly;
    
    always @ (posedge clock_i) begin
        last_dly <= last[LAST_PE_INDEX];
    end

    assign res_o = P[LAST_PE_INDEX+1];
    assign res_push_o = (last_loop_reg) ? (res_push[LAST_PE_INDEX] | last_dly) : 0;
    
    assign last_o = (last_loop_reg) ? last[LAST_PE_INDEX] : 0;

    // The last PE in the chain indicates that X data must be right shifted when it has captured
    // a block of X data.
    assign shift_X_o = shift_X[PE_NB-1];
    
endmodule
