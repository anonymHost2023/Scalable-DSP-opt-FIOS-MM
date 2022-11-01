`timescale 1ns / 1ps

// This module contains the control logic of PEs.
// Scheduling of DSP block operations is performed using a Mealy FSM.
// A non-DSP internal counter is used to indicate termination of the inner loop of a PE.
// This module also controls the clock enable signals of fixed input operands registers,
// the selection signals of PE multiplexers as well as fetch-from-previous-FIFO and
// push-to-next-FIFO signals for the circulation of operands between PEs.
// Finally this module ensure communication with the next PE and global FIFO module using
// the next_start_o, shift_X_o, res_push_o and last_o signals.

module PE_control #(parameter s = 16) (
    input clock_i, reset_i,
    
    input start_i,
    
    // Fixed input operands registers enable
    output reg X_reg_en_o,
    output reg m_reg_en_o,
    
    // DSP blocks inputs multiplexer control signals
    output reg [1:0] A_sel_o,
    output reg [1:0] B_sel_o,
    output reg [1:0] C_sel_o,
    
    output reg [8:0] OPMODE_o,

    // n and Y operands FIFO control signals    
    output reg n_fetch_o,
    output reg Y_fetch_o,
    
    output reg n_push_o,
    output reg Y_push_o,
    
    // output delay line and delay line bypass control signals
    output reg P_dly_en_o,
    output reg P_dly_bypass_o,
    
    // start of the next PE signal
    output reg next_start_o,

    // These three signals are declared in every PE but are only used by a single one.
    // shift_X_o indicates that every all PEs have captured a block of the X operand and
    // the X_i input to the global FIOS module must be shifted for the next blocks of X to be available.
    // res_push_o indicates that a result block of the full FIOS computation is available and should be stored.
    // last_o indicates that the last PE has completed its assignment and that the full FIOS computation is over.
    output reg shift_X_o,
    output reg res_push_o,
    output reg last_o
    
    );

    reg op_count_reset;
    reg op_count_en;
    reg [$clog2(s)-1:0] op_count;

    // FSM States. Note that states are named after which data is available at inputs A and B of the DSP block.
    localparam INIT = 5'b00000,
               X_Y0 = 5'b00001,
               X_Y1 = 5'b00010,
               X_Y2 = 5'b00011,
               M = 5'b00100,
               X_Y3 = 5'b00101,
               X_Y4 = 5'b00110,
               M_N0 = 5'b00111,
               M_N1 = 5'b01000,
               M_N2 = 5'b01001,
               M_N3 = 5'b01010,
               M_N4 = 5'b01011,
               X_Y5 = 5'b01100,
               M_N5 = 5'b01101,
               X_Y6 = 5'b01110,
               X_Y = 5'b01111,
               M_N = 5'b10000,
               LAST0 = 5'b10001,
               LAST1 = 5'b10010,
               LAST2 = 5'b10011;

    reg [4:0] current_state;
    reg [4:0] future_state;
               
    always @ (posedge clock_i) begin
        if (reset_i)
            current_state <= INIT;
        else
            current_state <= future_state;
    end

    always @ (current_state, start_i, op_count) begin
        case (current_state)
            // Start of PE operations is controlled by the previous PE's next_start_o signal.
            INIT : begin
                if (start_i)
                    future_state = X_Y0;
                else
                    future_state = INIT;
            end
            X_Y0 : future_state = X_Y1;
            X_Y1 : future_state = X_Y2;
            X_Y2 : future_state = M;
            M : future_state = X_Y3;
            X_Y3 : future_state = X_Y4;
            X_Y4 : future_state = M_N0;
            M_N0 : future_state = M_N1;
            M_N1 : future_state = M_N2;
            M_N2 : future_state = M_N3;
            M_N3 : future_state = M_N4;
            M_N4 : future_state = X_Y5;
            X_Y5 : future_state = M_N5;
            M_N5 : future_state = X_Y6;
            X_Y6 : future_state = M_N;
            X_Y : future_state = M_N;
            // Inner loop termination is tested in the M_N state.
            M_N : begin
                if(op_count == s-7)
                    future_state = LAST0;
                else
                    future_state = X_Y;
            end
            LAST0 : future_state = LAST1;
            LAST1 : future_state = LAST2;
            LAST2 : future_state = INIT;
            default : future_state = INIT;
        endcase
    end
    
    always @ (current_state) begin
        case (current_state)
            // INIT is the rest state of PEs.
            // in this state X operand blocks are continuously captured in the X_reg register.
            // DSPs are set to keep their current output, which is propagated in the output delay line.
            // Inner loop counter is reset.
            INIT : begin
                X_reg_en_o = 1;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 0;
                OPMODE_o = 9'b000100000;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 1;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // Calculation of the M parameter depends on the calculation of the X_Y0 product.
            // In order not to waste computation cycles, product X_Y0-X_Y4 are calculated while
            // data travels through the pipeline. Outputs of the previous PE are synchronized and added to these products.
            // The results are stored in a delay line for later addition to the M_N0-M_N4 products.
            // Y and n operand blocks are pushed to the Y and n FIFOs as soon as they are used, and are from the previous PE as late
            // as possible, one cycle before they are used.
            X_Y0 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 0;
                OPMODE_o = 9'b000100000;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 1;
                Y_push_o = 1;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            X_Y1 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 0;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            X_Y2 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 1;
                B_sel_o = 1;
                C_sel_o = 0;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // The X_Y0 product result is available, thus the 17 least significant bits are looped back to the
            // multiplicative input A of the DSP block for multiplication with the n_prime_0 parameter.
            // The 17 least significant bits of this result is the m parameter.
            M : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 0;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            X_Y3 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b000000101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            X_Y4 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 1;
                B_sel_o = 2;
                C_sel_o = 0;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // The M parameter is available and registered. The PE catches up to the X_Y0-X_Y4 products
            // and adds these intermediate results to the M_N0-M_N4 products.
            // output of the M_N(j) result is right-shifted by 17 bits and added to M_N(j+1).
            // The res_push signal indicated a result block is available at the output of the DSP block.
            M_N0 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 1;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 1;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 0;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            M_N1 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 1;
                OPMODE_o = 9'b110000101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 1;
                next_start_o = 0;
                last_o = 0;
            end
            // The next_start signal launches the computation of the next PE in the chain.
            M_N2 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 1;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 1;
                last_o = 0;
            end
            M_N3 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 1;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            M_N4 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 1;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // The PE adopts a regular behavior until the end of computations. Care is taken
            // to synchronize results and feed them to the next PE, through bypass of the output delay line
            // if need be.
            X_Y5 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 2;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            M_N5 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            X_Y6 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 2;
                OPMODE_o = 9'b000100101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 1;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // X_Y state schedules the X_Y multiplication, addition of the current PE output
            // right shifted 17 bits and addition of the previous PE output.
            X_Y : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 2;
                B_sel_o = 2;
                C_sel_o = 2;
                OPMODE_o = 9'b000100101;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 1;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // M_N state schedules accumulation of the current PE output and the M_N multiplication.
            // The result of this operation can be used by the next PE.
            M_N : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b111100101;
                n_fetch_o = 0;
                Y_fetch_o = 1;
                n_push_o = 1;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 1;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // The last few states complete the computation and indicate its end using the last_o signal.
            LAST0 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b000100101;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            LAST1 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b001100000;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
            // Last result is right-shifted 17 bits and kept as DSP output.
            LAST2 : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 2;
                OPMODE_o = 9'b000100000;
                n_fetch_o = 1;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 1;
                P_dly_en_o = 1;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 1;
            end
            default : begin
                X_reg_en_o = 0;
                m_reg_en_o = 0;
                A_sel_o = 0;
                B_sel_o = 0;
                C_sel_o = 0;
                OPMODE_o = 9'b000000000;
                n_fetch_o = 0;
                Y_fetch_o = 0;
                n_push_o = 0;
                Y_push_o = 0;
                res_push_o = 0;
                P_dly_en_o = 0;
                P_dly_bypass_o = 0;
                op_count_reset = 0;
                op_count_en = 0;
                shift_X_o = 0;
                next_start_o = 0;
                last_o = 0;
            end
        endcase
    end

    always @ (posedge clock_i) begin
        if (op_count_reset)
            op_count <= 0;
        else if (op_count_en)
            op_count <= op_count+1;
        else
            op_count <= op_count;
    end
    
endmodule
