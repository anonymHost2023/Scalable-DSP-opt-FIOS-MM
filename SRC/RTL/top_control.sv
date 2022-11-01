`timescale 1ns / 1ps

// This module is the global FSM of the top module. It is responsible for launching
// load/store memory operations and FIOS computation.
// It is the point of entry of the design and is started by the processor. It also
// signals the end of computations to the processor.

module top_control(
    input clock_i, reset_i,

    // The global routine is started by the processor.
    input start_i,

    // The memory module and arithmetic module status signals are used to transition between states.
    input load_done_i,
    input store_done_i,
    input FIOS_last_i,

    // These signals are used to launch submodules operations and toggle between load/store memory operation.
    output reg mem_start_o,
    output reg load_store_o,
    output reg FIOS_start_o,

    // The done status signal is sent to the processor once FIOS computation and result store are over.
    output reg done_o
    
    );
    
    localparam [3:0] RESET = 4'b0000,
                     INIT = 4'b0001,
                     LOAD = 4'b0010,
                     LOAD_LAST = 4'b0011,
                     FIOS_INIT = 4'b0100,
                     FIOS = 4'b0101,
                     STORE = 4'b0110,
                     DONE = 4'b0111;
    
    reg [3:0] current_state = RESET;
    reg [3:0] future_state = RESET;
    
    
    always @ (posedge clock_i) begin
        if (reset_i)
            current_state <= RESET;
        else
            current_state <= future_state;    
    end


    always @ (current_state, start_i, load_done_i, FIOS_last_i, store_done_i) begin
        case(current_state)
            RESET : future_state = INIT;
            // The processor starts the global routine by setting the start signal after loading operands
            // inside the block RAM.
            INIT : begin
                if (start_i)
                    future_state = LOAD;
                else
                    future_state = INIT;
            end
            // If operands are loaded, starts FIOS.
            // If FIOS is over, store results into BRAM and wait for reset.
            LOAD : begin
                if (load_done_i)
                    future_state = LOAD_LAST;
                else
                    future_state = LOAD;
            end
            LOAD_LAST : future_state = FIOS_INIT;
            FIOS_INIT : future_state = FIOS;
            FIOS : begin
                if (FIOS_last_i)
                    future_state = STORE;
                else
                    future_state = FIOS;
            end
            STORE : begin
                if (store_done_i)
                    future_state = DONE;
                else
                    future_state = STORE;
            end
            DONE : future_state = DONE;
            default : future_state = INIT;
        endcase
    end

    
    always @ (current_state) begin
        case(current_state)
            RESET : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
            INIT : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
            LOAD : begin
                mem_start_o = 1;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
            LOAD_LAST : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
            FIOS_INIT : begin
                mem_start_o = 0;
                FIOS_start_o = 1;
                load_store_o = 0;
                done_o = 0;
            end
            FIOS : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
            STORE : begin
                mem_start_o = 1;
                FIOS_start_o = 0;
                load_store_o = 1;
                done_o = 0;
            end
            DONE : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 1;
            end
            default : begin
                mem_start_o = 0;
                FIOS_start_o = 0;
                load_store_o = 0;
                done_o = 0;
            end
        endcase
    end
    
endmodule

