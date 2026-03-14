# 5-Stage Pipelined RV32I Core with Custom Graph Accelerator

> **Developed by Monish Chandra Janghel** | *Electronics and Communication Engineering, NIT Raipur* > 📄 **IEEE Publication:** [Accepted and Presented at IEEE INDICON (https://ieeexplore.ieee.org/document/11392913)](#)

A ground-up implementation of a 32-bit RISC-V processor (RV32I base integer instruction set) written entirely in SystemVerilog. This core features a classic 5-stage pipeline with full data forwarding, hazard detection, and a custom Instruction Set Architecture (ISA) extension specifically designed to accelerate graph traversal algorithms like Dijkstra and A*.

The core is rigorously verified using a custom Universal Verification Methodology (UVM) framework featuring a Shadow Register File Scoreboard for dynamic instruction prediction and golden model comparison.

## 📖 Abstract
Graph algorithms such as shortest-path and heuristic search form the computational backbone of applications in robotics, navigation, and communication networks. However, their tight inner loops remain performance bottlenecks on embedded CPUs, especially when branch-heavy or arithmetic-intensive kernels dominate execution. 

This paper proposes a minimalist yet powerful approach: a lightweight instruction set extension for RISC-V that directly accelerates core graph primitives. We introduce two custom instructions—**UMIN** (Unsigned Minimum) for branch-free selection and **ADIFF** (Absolute Difference) for efficient heuristic evaluation. These instructions are designed to integrate into a fully functional, hazard-aware 5-stage pipelined RV32I processor, replacing multi-instruction idioms with single operations, yielding consistent improvements across multiple graph kernels. 

Analytical cycle modeling shows up to **3x instruction count reduction** and up to **3.67× projected speedup** compared to standard branching baselines, while outperforming optimized branchless software by 3×. Our results demonstrate that carefully chosen, domain-relevant ISA extensions can deliver significant inner-loop efficiency within the footprint of a simple embedded CPU, striking a balance between programmability, performance, and modest hardware modifications.

**Index Terms** — RISC-V, ISA Extension, Custom Instruction, Graph Algorithms, Hardware Acceleration, Embedded Systems.

---

## 🚀 Key Architectural Features
* **5-Stage Pipeline:** Instruction Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Writeback (WB).
* **Hazard Resolution:** * Full internal data forwarding (bypassing) to resolve Read-After-Write (RAW) hazards without stalling.
  * Load-use hazard detection and pipeline stalling.
  * Control hazard flushing with precise branch target calculation.
* **Optimized Storage:** Register File implemented utilizing FPGA Distributed RAM (LUTRAM) for extreme area efficiency.

## ⚡ Custom Graph Accelerator (ISA Extension)
To eliminate branch prediction penalties during the heuristic calculations of pathfinding algorithms, the ALU was extended with custom instructions utilizing a dedicated opcode (`OP_CUSTOM_0: 7'b0001011`).

| Instruction | Funct3 | Opcode    | Operation | Application |
| :--- | :--- | :--- | :--- | :--- |
| **UMIN** | `3'b000` | `0001011` | `rd = min(rs1, rs2)` | Finding the lowest f_cost in an Open List. |
| **ADIFF**| `3'b001` | `0001011` | `rd = abs(rs1 - rs2)`| Calculating Manhattan Distance (dx/dy) seamlessly. |

*By executing Absolute Difference and Unsigned Minimum in a single clock cycle, this accelerator prevents pipeline flushes that would normally occur during the conditional branching of standard `if-else` heuristic math.*

## 🔬 Design Verification (UVM)
The core abandons standard directed testbenches in favor of an Object-Oriented **UVM** environment to prove mathematical perfection under pipeline stress.

* **Separation of Concerns:** Independent interfaces, monitors, and transactions to sample the pipeline cleanly via RVFI (RISC-V Formal Interface) tracking registers.
* **The Golden Predictor Scoreboard:** A custom `uvm_scoreboard` that decodes instructions in software, calculates the expected math using a Shadow Register File, and compares it against the hardware's Writeback stage dynamically.
* **Algorithm-Specific Kernels:** Verified against targeted assembly firmware for Fibonacci sequence generation, Dijkstra cost calculations, and A* Manhattan Distance heuristics.


> ⚠️ **Note on Implementation vs. Publication:** > The original IEEE INDICON publication discusses the foundational architecture implemented in standard Verilog. The codebase in this repository represents an upgraded, highly optimized iteration completely rewritten in **SystemVerilog**. Due to these architectural improvements, advanced data forwarding techniques, and the transition to SystemVerilog, the hardware utilization metrics (LUTs/FFs) and maximum clock frequency (Fmax) presented in this repository reflect a more efficient design and will differ from the baseline figures published in the paper.
## 📊 Synthesis & Implementation Results
Synthesized via Xilinx Vivado for standard FPGA deployment.

* **Target Clock Frequency ($F_{max}$):** 89.3 MHz (Passing WNS)
* **Look-Up Tables (LUTs):** 2253
* **LUTRAM:** 512
* **Flip-Flops (FF):** 1542
* **I/O Ports:** 66



