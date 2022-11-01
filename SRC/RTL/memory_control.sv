`timescale 1ns / 1ps

// This module is the FSM for the memory module. It schedules and controls loads of the operands from the BRAM to the
// internal registers, and store of result data form the registers to the BRAM.

module memory_control #(parameter s = 16) (
    input clock_i, reset_i,

    // start of memory operations and toggling of load data from BRAM/store data to BRAM
    // are controlled by the top_control FSM.
    input start_i,
    input load_store_i,
    
    // BRAM interface control signals.
    output reg BRAM_en_o,
    output reg BRAM_we_o,
    output wire [$clog2(4*s)-1:0] BRAM_addr_o,

    // Input operands register write signals.
    output reg X_reg_write_o,
    output reg n_prime_0_reg_en_o,
    output reg Y_reg_write_o,
    output reg n_reg_write_o,

    // Output result register read signal.
    output reg res_reg_read_o,

    // load/store done status signals.
    output reg load_done_o,
    output reg store_done_o
    );

    // An internal counter is used to generate BRAM read/write addresses.
    reg addr_count_reset;
    reg addr_count_en;
    reg [$clog2(4*s)-1:0] addr_count;

    localparam [4:0] RESET = 5'b00000,
                     INIT = 5'b00001,
                     LOAD_N = 5'b00010,
                     LOAD_N_PRIME_0 = 5'b00011,
                     LOAD_X = 5'b00100,
                     LOAD_Y = 5'b00101,
                     LOAD_DONE = 5'b00110,
                     STORE_RES = 5'b00111,
                     STORE_DONE = 5'b01000;

    reg [4:0] current_state = RESET;
    reg [4:0] future_state = RESET;

    always @ (posedge clock_i) begin
        if (reset_i)
            current_state <= RESET;
        else
            current_state <= future_state;
    end
    
    always @ (current_state, start_i, load_store_i, addr_count) begin
        case (current_state)
            RESET : future_state = INIT;
            // The load_store and start signal is asserted during the INIT state to determine whether the top module requests
            // a loas or store operation.
            INIT : begin
                if(start_i) begin
                    if (load_store_i)
                        future_state = STORE_RES;
                    else
                        future_state = LOAD_N;
                end else
                    future_state = INIT;
            end
            // Input data operands n, X and Y are stored using s 17 bits blocks
            // while the n_prime_0 operand only consists of a single 17 bits block.
            // Input operands are loaded in the order n, n_prime_0, X and Y.
            LOAD_N : begin
                if (addr_count == s-1)
                    future_state = LOAD_N_PRIME_0;
                else
                    future_state = LOAD_N;
            end
            LOAD_N_PRIME_0 : future_state = LOAD_X;
            LOAD_X : begin
                if (addr_count == 2*s)
                    future_state = LOAD_Y;
                else
                    future_state = LOAD_X;
            end
            LOAD_Y : begin
                if (addr_count == 3*s)
                    future_state = LOAD_DONE;
                else
                    future_state = LOAD_Y;
            end
            LOAD_DONE : future_state = INIT;
            // The FIOS result is stored using s 17 bits blocks.
            STORE_RES : begin
                if (addr_count == s-1)
                    future_state = STORE_DONE;
                else
                    future_state = STORE_RES;
            end
            STORE_DONE : future_state = INIT;
            default : future_state = INIT;
        endcase
    end

    always @ (current_state) begin
        case(current_state)
            RESET : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 1;
                addr_count_en = 0;
                BRAM_en_o = 0;
            end
            // The address counter is reset in the INIT state.
            INIT : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 1;
                addr_count_en = 0;
                BRAM_en_o = 0;
            end
            // The n operand is stored in BRAM at adresses 0 to s-1.
            LOAD_N : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 1;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 0;
                addr_count_en = 1;
                BRAM_en_o = 1;
            end
            // The n_prime_0 operand is stored in BRAM at adress s.
            LOAD_N_PRIME_0 : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 1;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 0;
                addr_count_en = 1;
                BRAM_en_o = 1;
            end
            // The X operand is stored in BRAM at adresses s+1 to 2*s.
            LOAD_X : begin
                BRAM_we_o = 0;
                X_reg_write_o = 1;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 0;
                addr_count_en = 1;
                BRAM_en_o = 1;
            end
            // The Y operand is stored in BRAM at adresses 2*s+1 to 3*s.
            LOAD_Y : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 1;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 0;
                addr_count_en = 1;
                BRAM_en_o = 1;
            end
            LOAD_DONE : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 1;
                store_done_o = 0;
                addr_count_reset = 1;
                addr_count_en = 0;
                BRAM_en_o = 1;
            end
            // The result is stored in BRAM at adresses 0 to s-1 and overwrites n.
            STORE_RES : begin
                BRAM_we_o = 1;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 1;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 0;
                addr_count_en = 1;
                BRAM_en_o = 1;
            end
            STORE_DONE : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 1;
                addr_count_reset = 1;
                addr_count_en = 0;
                BRAM_en_o = 1;
            end
            default : begin
                BRAM_we_o = 0;
                X_reg_write_o = 0;
                n_prime_0_reg_en_o = 0;
                Y_reg_write_o = 0;
                n_reg_write_o = 0;
                res_reg_read_o = 0;
                load_done_o = 0;
                store_done_o = 0;
                addr_count_reset = 1;
                addr_count_en = 0;
                BRAM_en_o = 0;
            end
        endcase
    end

    // Address counter.
    always @ (posedge clock_i) begin
        if(addr_count_reset | reset_i)
            addr_count <= 0;
        else if (addr_count_en)
            addr_count <= addr_count+1;
        else
            addr_count <= addr_count;
    
    end

    assign BRAM_addr_o = addr_count;
    
endmodule

