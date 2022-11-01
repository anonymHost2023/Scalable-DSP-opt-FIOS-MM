`timescale 1ns / 1ps


module PE #(parameter s = 16) (
    input clock_i,
    input reset_i,
    
    // Start signal issued by the previous PE in the chain or the global FIOS control FSM.
    input start_i,
    
    // input operand fetch signals received from the next PE in the chain.
    input n_fetch_i,
    input Y_fetch_i,
    
    // input operands. Fixed operands X_i and n_i are registered for a complete iteration of the PE FSM.
    // n_prime_0_i is fixed for the whole FIOS computation.
    // n_i and Y_i operand blocks are fetched from the previous PE in the chain or the memory unit.
    input [16:0] X_i,
    input [16:0] n_prime_0_i,
    input [16:0] Y_i,
    input [16:0] n_i,
    
    // Output and delayed output of the previous PE in the chain used as additive inputs to the DSP block.
    input [16:0] P_prev_i,
    input [16:0] P_prev_dly_i,
    
    // Output operands fed to the next PE in the chain using Y_FIFO and N_FIFO
    output [16:0] n_prime_0_o,
    output [16:0] Y_o,
    output [16:0] n_o,
    
    // Output and delayed output of the current PE.
    output [16:0] P_o,
    output [16:0] P_dly_o,
    
    // Operand fetch signals sent to the previous PE in the chain.
    output n_fetch_o,
    output Y_fetch_o,
    
    // This signal indicates a result block is available. It is only used by a single PE in the chain.
    output res_push_o,
    
    // These signal are only used by a single PE. They control the behavior of the global FIOS module (see PE_control). 
    output shift_X_o,
    output next_start_o,
    output last_o

    );
    
    wire [8:0] OPMODE;
    
    // DSP block input signals. A and B are multiplicative inputs while C is an additive input (see PE_AU).
    reg [16:0] A;
    reg [16:0] B;
    reg [34:0] C;
    
    // DSP block output signal.
    wire [34:0] P;

    // These signals are selection and registered selection signals to the multiplexers which control
    // the operands fed to the A, B and C DSP block inputs (see multiplexer description below).
    wire [1:0] A_sel;
    wire [1:0] B_sel;
    wire [1:0] C_sel;

    reg [1:0] A_sel_reg;
    reg [1:0] B_sel_reg;
    reg [1:0] C_sel_reg;

    // Fixed input operands registers and their clock enable signals (controlled by PE_control).
    wire X_reg_en;
    reg [16:0] X_reg;

    reg [16:0] n_prime_0_reg;

    wire m_reg_en;
    reg [16:0] m_reg;

    // DSP block output delay line, delay line bypass and enable signals. Used to synchronize between different PEs and
    // to synchronize the loop back to the C additive input.
    wire P_dly_en;
    wire P_dly_bypass;
    reg [34:0] P_dly [0:3];

    // n FIFO and Y FIFO push signals (see PE_control).
    wire n_push;
    wire Y_push;

    // Mux selection signals registers
    always @ (posedge clock_i) A_sel_reg <= A_sel;
    always @ (posedge clock_i) B_sel_reg <= B_sel;    
    always @ (posedge clock_i) C_sel_reg <= C_sel;

    // PE control FSM instance.
    PE_control #(.s(s)) PE_control_inst (
        .clock_i(clock_i),
        .reset_i(reset_i),
        
        .start_i(start_i),
        
        .X_reg_en_o(X_reg_en),
        .m_reg_en_o(m_reg_en),

        .A_sel_o(A_sel),
        .B_sel_o(B_sel),
        .C_sel_o(C_sel),
        
        .OPMODE_o(OPMODE),
        
        .n_fetch_o(n_fetch_o),
        .Y_fetch_o(Y_fetch_o),
        
        .n_push_o(n_push),
        .Y_push_o(Y_push),
        .res_push_o(res_push_o),
        
        .P_dly_en_o(P_dly_en),
        .P_dly_bypass_o(P_dly_bypass),
        
        .shift_X_o(shift_X_o),
        .next_start_o(next_start_o),
        .last_o(last_o)
    );

    // n and Y FIFOs instances.
    FIFO #(.WIDTH(17)) n_FIFO_inst (
        .clock_i(clock_i), .reset_i(reset_i),

        .write_en_i(n_push),
        .read_en_i(n_fetch_i),
        
        .data_i(n_i),
        .data_o(n_o)
    );

    FIFO #(.WIDTH(17)) Y_FIFO_inst (
        .clock_i(clock_i), .reset_i(reset_i),

        .write_en_i(Y_push),
        .read_en_i(Y_fetch_i),
        
        .data_i(Y_i),
        .data_o(Y_o)
    );

    // X_reg register.
    always @ (posedge clock_i) begin
        if (reset_i)
            X_reg <= 0;
        else if (X_reg_en)
            X_reg <= X_i;
        else
            X_reg <= X_reg;
    end

    // n_prime_0_reg register.
    always @ (posedge clock_i) begin
        if (reset_i)
            n_prime_0_reg <= 0;
        else
            n_prime_0_reg <= n_prime_0_i;
    end

    // m_reg register.
    always @ (posedge clock_i) begin
        if (reset_i)
            m_reg <= 0;
        else if (m_reg_en)
            m_reg <= P[16:0];
        else
            m_reg <= m_reg;
    end

    // P output delay line and bypass description.
    always @ (posedge clock_i) begin
        if (reset_i) begin
            P_dly[0] <= 0;
            P_dly[1] <= 0;
            P_dly[2] <= 0;
            P_dly[3] <= 0;
        end else if (P_dly_en) begin
            P_dly[0] <= P;
            P_dly[1] <= P_dly[0];
            P_dly[2] <= P_dly[1];
            if (P_dly_bypass)
                P_dly[3] <= P;
            else
                P_dly[3] <= P_dly[2];
        end else begin
            P_dly[0] <= P_dly[0];
            P_dly[1] <= P_dly[1];
            P_dly[2] <= P_dly[2];
            P_dly[3] <= P_dly[3];
        end
    end

    // A input multiplexer. Selects between X_reg, the 17 least significant bits of the P DSP block output
    // (for computation of the m parameter) and m_reg.
    always_comb begin
        case(A_sel_reg)
            0 : A = X_reg;
            1 : A = P[16:0];
            2 : A = m_reg;
            default : A = X_reg;
        endcase
    end

    // B input multiplexer. Selects between operand block Y_i, n_prime_0_reg (for computation of the m parameter)
    // and n_i operand block.
    always_comb begin
        case(B_sel_reg)
            0 : B = Y_i;
            1 : B = n_prime_0_reg;
            2 : B = n_i;
            default : B = Y_i;
        endcase
    end

    // C input multiplexer. Selects between the output and delayed output of the previous PE in the chain
    // and the output of the current PE's output delay line.
    always_comb begin
        case(C_sel_reg)
            0 : C = P_prev_i;
            1 : C = P_dly[2];
            2 : C = P_prev_dly_i;
            default : C = P_prev_dly_i;
        endcase
    end

    // DSP block instance.
    PE_AU PE_AU_inst (
        .clock_i(clock_i), .reset_i(reset_i),
        
        .OPMODE_i(OPMODE),
        
        .A_i(A),
        .B_i(B),
        .C_i(C),
        
        .P_o(P)
    );

    // Content of the n_prime_0_reg stays the same for the whole duration of FIOS computation.
    // It is directly transmitted to the next PE.
    assign n_prime_0_o = n_prime_0_reg;
    
    // Assignment of the current PE's output and delayed output signals.
    assign P_o = P;
    assign P_dly_o = P_dly[3];
    
endmodule
