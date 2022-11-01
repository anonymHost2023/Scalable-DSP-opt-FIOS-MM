`timescale 1ns / 1ps

// This module is essentially a wrapper for the DSP blocks used in a processing element.
// The DSP multiplier is used as a 17x17 bits unsigned multiplier, hence the 17-bit width of A_i and B_i inputs.
// Only the 35 least significant bits of DSP block output are non-zero During FIOS computation,
// hence the 35-bit width of P_o output and C_i additive input.
// DSP block operation are selected via the OPMODE signal controlled by the PE_control FSM.

module PE_AU(
    input clock_i, reset_i,
    input [16:0] A_i,
    input [16:0] B_i,
    input [34:0] C_i,
    input [8:0] OPMODE_i,
    output [34:0] P_o
    );

    wire [47:0] P;

    DSP48E2 #(
      .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
      .USE_SIMD("ONE48"),                // SIMD selection (FOUR12, ONE48, TWO24)
      .ACASCREG(1),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
      .ADREG(1),                         // Pipeline stages for pre-adder (0-1)
      .ALUMODEREG(1),                    // Pipeline stages for ALUMODE (0-1)
      .AREG(1),                          // Pipeline stages for A (0-2)
      .BCASCREG(1),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
      .BREG(1),                          // Pipeline stages for B (0-2)
      .CARRYINREG(1),                    // Pipeline stages for CARRYIN (0-1)
      .CARRYINSELREG(1),                 // Pipeline stages for CARRYINSEL (0-1)
      .CREG(1),                          // Pipeline stages for C (0-1)
      .DREG(1),                          // Pipeline stages for D (0-1)
      .INMODEREG(1),                     // Pipeline stages for INMODE (0-1)
      .MREG(1),                          // Multiplier pipeline stages (0-1)
      .OPMODEREG(1),                     // Pipeline stages for OPMODE (0-1)
      .PREG(1)                           // Number of pipeline stages for P (0-1)
   )
   DSP48E2_inst (
      .P(P),                           // 48-bit output: Primary data
      .ALUMODE(0),               // 4-bit input: ALU control
      .CARRYINSEL(0),         // 3-bit input: Carry select
      .CLK(clock_i),                       // 1-bit input: Clock
      .INMODE(0),                 // 5-bit input: INMODE control
      .OPMODE(OPMODE_i),                 // 9-bit input: Operation mode
      // Data inputs: Data Ports
      .A({{13{1'b0}}, A_i}),                           // 30-bit input: A data
      .B({1'b0, B_i}),                           // 18-bit input: B data
      .C({{13{1'b0}},C_i}),                           // 48-bit input: C data
      .CEA1(1),                     // 1-bit input: Clock enable for 1st stage AREG
      .CEA2(1),                     // 1-bit input: Clock enable for 2nd stage AREG
      .CEAD(1),                     // 1-bit input: Clock enable for ADREG
      .CEALUMODE(1),           // 1-bit input: Clock enable for ALUMODE
      .CEB1(1),                     // 1-bit input: Clock enable for 1st stage BREG
      .CEB2(1),                     // 1-bit input: Clock enable for 2nd stage BREG
      .CEC(1),                       // 1-bit input: Clock enable for CREG
      .CECARRYIN(1),           // 1-bit input: Clock enable for CARRYINREG
      .CECTRL(1),                 // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
      .CED(1),                       // 1-bit input: Clock enable for DREG
      .CEINMODE(1),             // 1-bit input: Clock enable for INMODEREG
      .CEM(1),                       // 1-bit input: Clock enable for MREG
      .CEP(1),                       // 1-bit input: Clock enable for PREG
      .RSTA(0),                     // 1-bit input: Reset for AREG
      .RSTALLCARRYIN(0),   // 1-bit input: Reset for CARRYINREG
      .RSTALUMODE(0),         // 1-bit input: Reset for ALUMODEREG
      .RSTB(0),                     // 1-bit input: Reset for BREG
      .RSTC(0),                     // 1-bit input: Reset for CREG
      .RSTCTRL(0),               // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
      .RSTD(0),                     // 1-bit input: Reset for DREG and ADREG
      .RSTINMODE(0),           // 1-bit input: Reset for INMODEREG
      .RSTM(0),                     // 1-bit input: Reset for MREG
      .RSTP(reset_i)                      // 1-bit input: Reset for PREG
   );

    assign P_o = P[34:0];

endmodule
