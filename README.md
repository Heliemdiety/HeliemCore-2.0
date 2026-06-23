# Hardware Accelerated RV32I SoC via Custom ISA & AXI4 Memory Subsystem

> **Developed by Monish Chandra Janghel** | *Electronics and Communication Engineering, NIT Raipur* > 📄 **IEEE Publication:** [Accepted and Presented at IEEE INDICON](https://ieeexplore.ieee.org/document/11392913)

A ground-up implementation of a 32-bit RISC-V processor (RV32I base integer instruction set) written entirely in SystemVerilog. This core features a classic 5-stage pipeline with dual-domain hazard resolution, an **AMBA AXI4-Full memory subsystem**, full data forwarding, hazard detection, and a custom Instruction Set Architecture (ISA) extension specifically designed to accelerate graph traversal algorithms like Dijkstra and A*.

The core is rigorously verified using a custom Universal Verification Methodology (UVM) framework featuring a Shadow Register File Scoreboard for dynamic instruction prediction and golden model comparison.

## 📖 Abstract
Graph algorithms such as shortest-path and heuristic search form the computational backbone of applications in robotics, navigation, and communication networks. However, their tight inner loops remain performance bottlenecks on embedded CPUs, especially when branch-heavy or arithmetic-intensive kernels dominate execution. 

This paper proposes a minimalist yet powerful approach: a lightweight instruction set extension for RISC-V that directly accelerates core graph primitives. We introduce two custom instructions—**UMIN** (Unsigned Minimum) for branch-free selection and **ADIFF** (Absolute Difference) for efficient heuristic evaluation. These instructions are designed to integrate into a fully functional, hazard-aware 5-stage pipelined RV32I processor, replacing multi-instruction idioms with single operations, yielding consistent improvements across multiple graph kernels. 

Analytical cycle modeling shows up to **3x instruction count reduction** and up to **3.67× projected speedup** compared to standard branching baselines, while outperforming optimized branchless software by 3×. Our results demonstrate that carefully chosen, domain-relevant ISA extensions can deliver significant inner-loop efficiency within the footprint of a simple embedded CPU, striking a balance between programmability, performance, and modest hardware modifications.

**Index Terms** — RISC-V, ISA Extension, Custom Instruction, Graph Algorithms, Hardware Acceleration, Embedded Systems.

---

<img width="1381" height="645" alt="Screenshot 2025-12-09 203242" src="https://github.com/user-attachments/assets/1d410ae4-0692-4bd7-886d-8a8e67d10e65" />






## 🚀 Latest Architecture Update: AXI4-Full Memory Subsystem
HeliemCore has been upgraded from a standard 1-cycle academic memory model to a professional, non-blocking **AMBA AXI4-Full** memory subsystem to interface with standard DDR memory controllers.
* **Decoupled FSMs:** Independent tracking of `AW`, `W`, and `B` channels for simultaneous address/data phase dispatch.
* **Latency Masking:** Implemented 1-deep Store Buffers to prevent pipeline stalls during main memory writes.
* **Critical-Word-First:** Architected Line Fill Buffers using AXI `WRAP` bursts to instantly wake up the CPU pipeline on Cache Misses.

## 🚀 Key Architectural Features
* **5-Stage Pipeline:** Instruction Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Writeback (WB).
* **Hazard Resolution:** * Full internal data forwarding (bypassing) to resolve Read-After-Write (RAW) hazards without stalling.
  * Load-use hazard detection and pipeline stalling.
  * Control hazard flushing with precise branch target calculation.
* **Optimized Storage:** Register File implemented utilizing FPGA Distributed RAM (LUTRAM) for extreme area efficiency.

## ⚡ Custom Graph Accelerator (ISA Extension)
To eliminate branch prediction penalties during the heuristic calculations of pathfinding algorithms, the Decode stage and ALU were extended with custom instructions utilizing a dedicated opcode (`OP_CUSTOM_0: 7'b0001011`).

| Instruction | Funct3 | Opcode    | Operation | Application |
| :--- | :--- | :--- | :--- | :--- |
| **UMIN** | `3'b000` | `0001011` | `rd = min(rs1, rs2)` | Finding the lowest f_cost in an Open List. |
| **ADIFF**| `3'b001` | `0001011` | `rd = abs(rs1 - rs2)`| Calculating Manhattan Distance (dx/dy) seamlessly. |

*By executing Absolute Difference and Unsigned Minimum in a single clock cycle, this accelerator prevents pipeline flushes that would normally occur during the conditional branching of standard `if-else` heuristic math.*

<br />
<br />

<img width="1357" height="660" alt="Screenshot 2025-12-11 132255" src="https://github.com/user-attachments/assets/13456688-a814-460d-9a31-a515ede44363" />
<br />
<br />

<img width="1361" height="660" alt="Screenshot 2025-12-11 134024" src="https://github.com/user-attachments/assets/61645c79-b55c-43aa-b951-518741271041" />


<br />
<br />



<table align="center" border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/31501116-95c8-4ea3-bcab-a8cdd87405e4" width="95%" alt="Instruction Count" />
      <br />
      <b>📊 Instruction Count</b>
      <p><i></i></p>
    </td>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/d0d4c576-84ea-4a8e-b0a1-d37f76cc1c39" width="95%" alt="Cycle Count" />
      <br />
      <b>⚡ Cycle Count</b>
      <p><i></i></p>
    </td>
  </tr>
</table>



> [!NOTE]
> **Performance Observations**
> * **LIMITATION: BELLMAN-FORD** Shows no performance gain. The algorithm relies on signed comparisons for negative edge weights, which are incompatible with the unsigned UMIN instruction. This forces the fallback to the standard software baseline ...
> * **IDEAL USE CASE: PRIM'S MST** Demonstrates the ideal scenario. Its pure "update-if smaller" kernel maps directly to a single UMIN instruction. This results in a 5x speedup (1 cycle vs. 5 cycles) over the branchless software equivalent.




## 🔬 Design Verification (UVM)
The core abandons standard directed testbenches in favor of an Object-Oriented **UVM** environment to prove mathematical perfection under pipeline stress.

* **Separation of Concerns:** Independent interfaces, monitors, and transactions to sample the pipeline cleanly via RVFI (RISC-V Formal Interface) tracking registers.
* **The Golden Predictor Scoreboard:** A custom `uvm_scoreboard` that decodes instructions in software, calculates the expected math using a Shadow Register File, and compares it against the hardware's Writeback stage dynamically.
* **Algorithm-Specific Kernels:** Verified against targeted assembly firmware for Fibonacci sequence generation, Dijkstra cost calculations, and A* Manhattan Distance heuristics.


> ⚠️ **Note on Implementation vs. Publication:** > The original IEEE INDICON publication discusses the foundational architecture implemented in standard Verilog. The codebase in this repository represents an upgraded, highly optimized iteration completely rewritten in **SystemVerilog**. Due to these architectural improvements, advanced data forwarding techniques, and the transition to SystemVerilog, the hardware utilization metrics (LUTs/FFs) and maximum clock frequency (Fmax) presented in this repository reflect a more efficient design and will differ from the baseline figures published in the paper.
## 📊 Synthesis & Implementation Results
Synthesized via Xilinx Vivado for standard FPGA deployment.
> **Note for Synthesis/Timing:** To synthesize without running out of physical I/O pins, run `set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]` in the Vivado Tcl console before running synthesis.
* **Target Clock Frequency ($F_{max}$):** 111 MHz (Passing WNS)
* **Look-Up Tables (LUTs):** 1843
* **Flip-Flops (FF):** 1745
* *Timing closure optimizations improved Fmax from 92.2 MHz to 111 MHz with a modest increase in area.*
---
<p align="center">
<small><i>© 2026 IEEE. Personal use of this material is permitted. Permission from IEEE must be obtained for all other uses. Certain figures and data points are adapted from the author's original work presented at INDICON 2026.</i></small>
</p>

