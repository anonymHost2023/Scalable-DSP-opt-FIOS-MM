This repository contains the sources, verification systems and implementation utilities for the hardware described in the HOST 2023 submission Scalable DSP optimized Montgomery Multiplier.
=======
This repository contains the sources, verification systems and implementation utilities for the hardware described in the HOST 2023 submission Scalable DSP optimized Montgomery Multiplier. The hardware has been developed using Vivado 2022.1.

# FIOS Montgomery Multiplier Implementation Results

Below are the lastest implementation results on a Zynq Ultrascale+ FPGA (ZCU102 platform, part xczu9eg-ffvb1156-2-e).

| WIDTH | Max Freq (MHz) | Latency | time (mus) | DSP | LUT | AT[^1] |
|-------|----------------|---------|------------|-----|-----|---- |
|128    |700             |84       |0.12        |3    |559  |106  |
|256    |700             |172      |0.246       |5    |900  |355  |
|512    |700             |337      |0.481       |8    |1428 |1103 |
|1024   |700             |667      |0.953       |15   |2634 |4055 |
|2048   |700             |1327     |1.90        |28   |4950 |15151|
|4096   |675             |2658     |3.94        |55   |9814 |62071|

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

This project will load the design, its testbench and test vectors stored in the `TXT` subfolder. 
Users can run simulations using these test vectors for sizes of operands (128, 256, 512, 1024, 2048, 4096).
Operand width can be modified using the `WIDTH` parameter of the testbench and by modifying the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design.

## FIOS_impl

A generation script for the implementation project is available in the `TCL` folder and can be run using

```
vivado -mode batch -source TCL/impl_project_gen.tcl
```

This project will load the design sources, create the implementation block design and link the design to the Zynq SoC.
Implementation strategies will be set to `Performance_ExploreWithRemap`.
Operand width can be modified using the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design. Implementation clock frequency can be modified using the output clock properties of
the `clock wizard` module in the block design.


