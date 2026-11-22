/*
 * Tiny Tapeout SKY130 -- RO-PUF V6
 * Four independent seven-inverting-stage ring oscillators, sharing
 * two independently controlled 4:1 MUXes for two raw frequency outputs.
 *
 * Each ring uses 6 SKY130 inverter cells and 1 NAND enable cell.
 * The oscillators are physical feedback circuits. Ideal RTL simulation
 * cannot verify oscillation, frequency, or physical PUF properties.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

(* keep_hierarchy = "yes" *)
module ro_puf_v6_ring_7 (
    input  wire en,
    output wire osc_out
);
    (* keep = "true" *) wire [6:0] ring;

    // The NAND is an inverting stage and also controls the oscillation.
    // When en=0, the loop settles to a static state.
    (* keep = "true", dont_touch = "true" *)
    sky130_fd_sc_hd__nand2_1 u_enable (
        .A(ring[6]),
        .B(en),
        .Y(ring[0])
    );

    genvar stage;
    generate
        for (stage = 0; stage < 6; stage = stage + 1) begin : g_inv
            (* keep = "true", dont_touch = "true" *)
            sky130_fd_sc_hd__inv_2 u_inv (
                .A(ring[stage]),
                .Y(ring[stage + 1])
            );
        end
    endgenerate

    assign osc_out = ring[6];
endmodule

module tt_um_ro_puf_4_v6 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // ui_in[1:0] : select RO 0..3 for MUX A
    // ui_in[3:2] : select RO 0..3 for MUX B
    // ui_in[4]   : shared local ring enable
    // uo_out[0]  : raw frequency output from MUX A
    // uo_out[1]  : raw frequency output from MUX B
    // Both MUXes select from the SAME four physical oscillators.
    // Selecting the same index gives two branches of the same RO signal.

    wire run = ena & rst_n & ui_in[4];
    (* keep = "true" *) wire [3:0] oscillator_signals;

    genvar ro_index;
    generate
        for (ro_index = 0; ro_index < 4; ro_index = ro_index + 1) begin : g_ro
            (* keep = "true", dont_touch = "true" *)
            ro_puf_v6_ring_7 u_ring (
                .en(run),
                .osc_out(oscillator_signals[ro_index])
            );
        end
    endgenerate

    // Two separately controlled 4:1 multiplexers.
    (* keep = "true" *) wire selected_a = oscillator_signals[ui_in[1:0]];
    (* keep = "true" *) wire selected_b = oscillator_signals[ui_in[3:2]];

    // Force both outputs low if the oscillators are disabled.
    assign uo_out = {6'b000000, (run & selected_b), (run & selected_a)};

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Unused external inputs. 'clk' is not used for the ROs.
    wire _unused = &{clk, ui_in[7:5], uio_in, 1'b0};
endmodule

`default_nettype wire
