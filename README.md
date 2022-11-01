# Generating Projects

## VERIFICATION

Verification utilities for the design are available in the `VERIFICATION` folder.
Test vectors can be generated using the `gen_test_vectors.sage.py` script (see `gen_test_vectors.sage.py -h` for help).
Test vectors stored in the TXT subfolder are imported to the simulation project of the design by default.

## FIOS_sim

A generation script for the simulation project is available in the `TCL` folder and can be run using

```
Vivado -mode batch -source TCL/sim_project_gen.tcl
```

This project will load the design, its testbench and test vectors stored in the `TXT` subfolder. 
Users can run simulations using these test vectors for sizes of operands (128, 256, 512, 1024, 2048, 4096).
Operand width can be modified using the `WIDTH` parameter of the testbench and my modifying the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design.

## FIOS_impl

A generation script for the implementation project is available in the `TCL` folder and can be run using

```
Vivado -mode batch -source TCL/sim_project_gen.tcl
```

This project will load the design sources, create the implementation block design and link the design to the Zynq SoC.
Implementation strategies will be set to `Performance_ExploreWithRemap`.
Operand width can be modified using the generic `WIDTH` parameter of the
`top_v_wrapper` module in the block design. Implementation clock frequency can be modified using the output clock properties of
the `clock wizard` module in the block design.

#
