
RISC-V Formal Verification Framework
====================================

This Fork
---------

This version of the riscv-formal repo contains the verification infrastructure for the [OtterMCU](https://github.com/rpeters54/OtterMCU) and [StoatMCU](https://github.com/rpeters54/StoatMCU).

This module includes an updated version of the `genchecks.py` build script for generating the checks that fixes up some of the weird path handling.

To build each core and run checks:
```bash
# Enter the cores directory
cd cores

# Generate the checks directory for the DUT
./genchecks.py --corename stoat --cfgname checks --basedir ~/riscv-formal

# Run the checks on that core
# Note: replace (nprocs) with the number of parallel sby tasks to run at a time
cd stoat
make -C checks -j(nprocs)
```

Bugs Found:
-----------

### OtterMCU:

- Allowed illegal instructions
- jalr is supposed to clear its lsb
- multi-cycle stalls can not rely on imem value remaining constant

Adding Your Core:
------------------

The `cores/example` directory includes a set of files to attach the riscv-formal interface without CSRs to your core.
- `rvfi_wrapper.sv`: The top file that connects a core to riscv-formal checks.
- `otter_rvfi.v`:    A module that drives the riscv-formal interface for a core.
- `rvfi_defines.vh`: Defines useful macros for attaching RVFI to a core.

### Adding RVFI

Begin by copying your verilog source files into the `cores/example/rtl` directory.
In the top-module of your core (e.g. `otter_mcu.v` or something similar), instantiate the `otter_rvfi.v` module.
The purpose of each input to the `otter_rvfi.v` module are documented inside it.

```verilog

    //=========================//
    // INSIDE YOUR TOP MODULE:
    //=========================//

    //----------------------------------------------------------------------------//
    // RISC-V Formal Interface: Set of Bindings Used in Sim to Verify Correctness
    //----------------------------------------------------------------------------//

`ifdef RISCV_FORMAL

    otter_rvfi u_otter_rvfi (
        .i_clk             (/* clk signal */),
        .i_rst             (/* active-high reset */),
        .i_valid           (/* valid signal (1 if a new instruction will be fetched next cycle) */),
        .i_excp            (/* 1 if an interrupt occurs this cycle */),
        .i_trap            (/* 1 if a synchronous trap occurs this cycle */),

        .i_instrn          (/* instruction signal */),

        .i_is_reg_type     (/* add, sub, etc. */),
        .i_is_imm_type     (/* addi, slti, etc. */),
        .i_is_load         (/* lb, lh, lw, etc. */),
        .i_is_store        (/* sb, sh, sw */),
        .i_is_branch       (/* beq, bnez, etc. */),
        .i_is_jal          (/* jal */),
        .i_is_jalr         (/* jalr */),
        .i_is_csr_write    (/* csrrw (can be wired zero if unimplemented) */),

        .i_br_taken        (/* 1 if branch taken */),
        .i_pc_addr         (/* current pc address */),
        .i_br_tgt_addr     (/* jump/branch instruction target address */),
        .i_epc_addr        (/* exception address, mepc or mtvec depending on type */),

        .i_rfile_we        (/* rfile write-enable */),
        .i_rfile_w_data    (/* rfile write data */),
        .i_rfile_r_rs1     (/* rfile rs1 read data */),
        .i_rfile_r_rs2     (/* rfile rs2 read data */),

        .i_dmem_sel        (/* byte mask for data memory */),
        .i_dmem_addr       (/* address read from/written to in dmem */),
        .i_dmem_r_data     (/* data read from dmem */),
        .i_dmem_w_data     (/* data written to dmem */),

        `RVFI_INTERCONNECTS
        ._dummy(1'b0)
    );

`endif

```

Once added, use the `RVFI_OUTPUTS` macro to add the the RVFI signals to the outputs of your top module.

```verilog

//=================================================//
// YOUR TOP MODULE SHOULD LOOK SOMETHING LIKE THIS
//=================================================//

`include "rvfi_defines.vh"

module otter_mcu #(
    parameter RESET_VEC = 32'h0
) (
    input             i_clk,
    input             i_rst, 
    input      [31:0] i_intrpt, 

`ifdef RISCV_FORMAL
    `RVFI_OUTPUTS
`endif

    input      [31:0] i_imem_r_data,
    output     [31:0] o_imem_addr,

    input      [31:0] i_dmem_r_data,
    output reg        o_dmem_re,
    output reg        o_dmem_we,
    output     [3:0]  o_dmem_sel,
    output     [31:0] o_dmem_addr,
    output     [31:0] o_dmem_w_data
);
```

Inside `rvfi_wrapper.sv`, update the mcu instantiation to match the name and signals used by your core.

```verilog

//=================================//
// UPDATE THIS TO MATCH YOUR CORE:
//=================================//

(* keep *) `rvformal_rand_reg [31:0] w_intrpt;
(* keep *) `rvformal_rand_reg [31:0] w_imem_r_data;
(* keep *) `rvformal_rand_reg [31:0] w_dmem_r_data;

(* keep *) wire [31:0] w_imem_addr;
(* keep *) wire        w_dmem_re;
(* keep *) wire        w_dmem_we;
(* keep *) wire [ 3:0] w_dmem_sel;
(* keep *) wire [31:0] w_dmem_addr;
(* keep *) wire [31:0] w_dmem_w_data;

otter_mcu # (
    .RESET_VEC('0)
) u_otter_mcu (
    .i_clk          (clock),
    .i_rst          (reset),
    .i_intrpt       (w_intrpt),

    `RVFI_INTERCONNECTS

    .i_imem_r_data  (w_imem_r_data),
    .o_imem_addr    (w_imem_addr),

    .i_dmem_r_data  (w_dmem_r_data),
    .o_dmem_re      (w_dmem_re),
    .o_dmem_we      (w_dmem_we),
    .o_dmem_sel     (w_dmem_sel),
    .o_dmem_addr    (w_dmem_addr),
    .o_dmem_w_data  (w_dmem_w_data)
);
```

With those additions, use `genchecks.py` to generate the checks for the core, and try running the checks with `make`.

```bash
# Enter the cores directory
cd cores
./genchecks.py --corename example --cfgname checks --basedir ~/riscv-formal

cd example
make -C checks -j(nprocs)
```

Dicussion
---------

After getting the checks running, look at the counterexample waveforms for at least three failing tests

For each, include a screenshot of the counterexample and discuss:

1. What assertion in the check failed; what is it testing for?
2. What behavior caused the failing example, was it a misinterpretation of the spec, wiring issue, etc.?
3. What changes do you think would fix the issue, and why?

*Note: if you are lucky enough to not fail three checks, you may introduce a bug into one of your modules and discuss the check that detects the fault.*

Deliverables
------------

Please include the following in your submission:

1. Your modified verilog file that instantiates and connects to the `otter_rvfi`.
2. The updated `rvfi_wrapper.sv` that connects to your core
3. A separate `.pdf` that contains your responses to the discussion questions.


END OF CHANGES
==============


About
-----

`riscv-formal` is a framework for formal verification of RISC-V processors.

It consists of the following components:
- A processor-independent formal description of the RISC-V ISA
- A set of formal testbenches for each processor supported by the framework
- The specification for the [RISC-V Formal Interface (RVFI)](docs/source/rvfi.rst) that must be
  implemented by a processor core to interface with `riscv-formal`.
- Some auxiliary proofs and scripts, for example to prove correctness of the ISA spec against
  riscv-isa-sim.

See [cores/picorv32/](cores/picorv32/) for example bindings for the PicoRV32 processor core.

A processor core usually will implement RVFI as an optional feature that is only enabled for verification. Sequential equivalence check can be used to prove equivalence of the processor versions with and without RVFI.

The current focus is on implementing formal models of all instructions from the RISC-V RV32I and RV64I ISAs, and formally verifying those models against the models used in the RISC-V "Spike" ISA simulator.

`riscv-formal` uses the FOSS SymbiYosys formal verification flow. All properties are expressed using immediate assertions/assumptions for maximal compatibility with other tools.

Documentation is available at https://riscv-formal.readthedocs.io/.

Configuring a new RISC-V processor
----------------------------------

1. Create a `riscv-formal/cores/<core-name>/` directory
2. Write a wrapper module that instantiates the core under test and abstracts models of necessary
   peripherals (usually just memory)
   - Use the [RVFI helper macros](docs/source/config.rst#rvfi_wires-rvfi_outputs-rvfi_inputs-rvfi_conn)
     `RVFI_OUTPUTS` and `RVFI_CONN` for quickly defining wrapper connections
   - See [picorv32/wrapper.sv](cores/picorv32/wrapper.sv) for a simple example wrapper
3. Write a `checks.cfg` config file for the new core
   - See [nerv/checks.cfg](cores/nerv/checks.cfg) for an example utilising most of the checks
   - Refer to [The riscv-formal Verification Procedure](docs/source/procedure.rst) for a complete
     guide on available checks, and a more detailed view of using `genchecks.py`
4. Generate checks with `python3 ../../checks/genchecks.py` from the `<core-name>` directory
   - Checks are generated in `riscv-formal/cores/<core-name>/checks`
5. Run checks with `make -C checks j$(nproc)`

### Notes

- The [quickstart guide](docs/source/quickstart.rst) goes through the process of running riscv-formal with
  some of the included cores.  It is recommended to follow this guide before adding a new core.
- See [picorv32/Makefile](cores/picorv32/Makefile) for an example makefile to manage generation and
  execution of checks.
- Out of tree generation with `genchecks.py` is not currently supported.
- Refer to [docs/source/config.rst](docs/source/config.rst) and [docs/source/procedure.rst](docs/source/procedure.rst) for a
  breakdown of how to use riscv-formal checks without using `genchecks.py`.
- The [cover check](docs/source/procedure.rst#cover) can be used to help determine the depth needed for the
  core to reach certain states as needed for other checks.

Funding
-------

`riscv-formal` checks for memory buses, CSRs, and the B extension were made
possible with funding from Sandia National Laboratories.

Sandia National Laboratories is a multimission laboratory operated by National
Technology and Engineering Solutions of Sandia LLC, a wholly owned subsidiary of
Honeywell International Inc., for the U.S. Department of Energy's National
Nuclear Security Administration. Sandia Labs has major research and development
responsibilities in nuclear deterrence, global security, defense, energy
technologies and economic competitiveness, with main facilities in Albuquerque,
New Mexico, and Livermore, California.
