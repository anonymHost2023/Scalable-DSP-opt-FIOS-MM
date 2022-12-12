This repository contains the sources, verification systems and implementation utilities for the hardware described in the HOST 2023 submission Scalable DSP optimized Montgomery Multiplier. The hardware has been developed using Vivado 2022.1.

# FIOS Montgomery Multiplier Implementation Results

Below are the lastest implementation results on a Zynq Ultrascale+ FPGA (ZCU102 platform, part xczu9eg-ffvb1156-2-e).
Note that the 738 MHz maximum frequency of designs using bit width ranging from 128 to 2048 bits is the maximum operating
frequency of BRAM blocks used on the xczu9eg-ffvb1156-2-e FPGA part (speed grade -2). Although the FIOS multiplier can
technically run at a slightly higher frequency (up to the 775 MHz maximum frequency of DSP blocks), it is the limit of
the current design methodology since one BRAM block is used as a clock domain crossing element in the implementation design
which has the Zynq+ System on Chip communicate with the FPGA FIOS accelerator.


| WIDTH | Max Freq (MHz) | Latency | time (mu s) | DSP | LUT | AT[^1] |
|-------|----------------|---------|-------------|-----|-----|--------|
|128    |738             |84       |0.114        |3    |583  |103     |
|256    |738             |172      |0.233        |5    |934  |343     |
|512    |738             |337      |0.457        |8    |1470 |1066    |
|1024   |738             |667      |0.904        |15   |2735 |3936    |
|2048   |738             |1327     |1.80         |28   |5025 |14473   |
|4096   |712.5           |2658     |3.73         |55   |9774 |58621   |


[^1]: Area Time product is computed as the product of the total equivalent LUT cost by the execution time.
  It is a measure of the efficiency of the system (the lower the better).
  The equivalent LUT cost of a DSP block is computed as $LUT_{eq} = \dfrac{LUT_{tot}}{DSP{tot}} = \dfrac{274080}{2520} = 108$

# Verification

Verification utilities for the design are available in the `VERIFICATION` folder.
Test vectors can be generated using the [sagemath toolchain](https://www.sagemath.org/) and the `gen_test_vectors.sage` script (see `sage gen_test_vectors.sage -h` for help).
Test vectors stored in the TXT subfolder are imported to the simulation project of the design by default.

# Generating Projects

## FIOS_sim

A generation script for the simulation project is available in the `TCL` folder and can be run using

```
vivado -mode batch -source TCL/sim_project_gen.tcl
```

This script will load the design, its testbench and test vectors stored in the `TXT` subfolder. 
Users can run simulations using these test vectors for sizes of operands (128, 256, 512, 1024, 2048, 4096).
Operand width can be modified using the `WIDTH` parameter of the testbench and by modifying the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design.

## FIOS_impl

A generation script for the implementation project is available in the `TCL` folder and can be run using

```
vivado -mode batch -source TCL/impl_project_gen.tcl
```

This script will load the design sources, create the implementation block design and link the design to the Zynq SoC.
It will also generate a bitstream for the project (which might take a few minutes) and the .xsa hardware definition file used in the Vitis codesign project.
Implementation strategies will be set to `Performance_ExploreWithRemap`.
Operand width can be modified using the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design. Implementation clock frequency can be modified using the output clock properties of
the `clock wizard` module in the block design.

## Vitis project

A generation script for a Vitis codesign project is available in the `TCL` folder and can be run using

```
xsct TCL/vitis_FIOS_256_gen.tcl
```

This script will create a new vitis workspace, generate a platform for the ZCU102 board using the previously generated .xsa file and generate a codesign application used to test a 256 bits FIOS Montgomery multiplication directly on the board.
