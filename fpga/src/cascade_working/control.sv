module control(
    input  logic              clk,
    input  logic              reset,          // active low
    input  logic              output_ready,   // safe to update, 1 cycle pulse
    input  logic              update_en,      // SPI update pulse
    input  logic [335:0]      data,

    // Low-pass (LPF)
    output logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2,

    // Mid-pass (BPF)
    output logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2,

    // High-pass (HPF)
    output logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2
);

    // ======================
    // ACTIVE COEFFICIENTS
    // (used by the filters)
    // ======================
    logic signed [15:0] low_b0_r, low_b1_r, low_b2_r, low_a1_r, low_a2_r;
    logic signed [15:0] mid_b0_r, mid_b1_r, mid_b2_r, mid_a1_r, mid_a2_r;
    logic signed [15:0] high_b0_r, high_b1_r, high_b2_r, high_a1_r, high_a2_r;

    // OUTPUT ASSIGNMENTS
    assign low_b0  = low_b0_r;
    assign low_b1  = low_b1_r;
    assign low_b2  = low_b2_r;
    assign low_a1  = low_a1_r;
    assign low_a2  = low_a2_r;

    assign mid_b0  = mid_b0_r;
    assign mid_b1  = mid_b1_r;
    assign mid_b2  = mid_b2_r;
    assign mid_a1  = mid_a1_r;
    assign mid_a2  = mid_a2_r;

    assign high_b0 = high_b0_r;
    assign high_b1 = high_b1_r;
    assign high_b2 = high_b2_r;
    assign high_a1 = high_a1_r;
    assign high_a2 = high_a2_r;

    // ======================
    // STAGING REGISTERS
    // (store coefficients from SPI, waiting to commit)
    // ======================
    logic signed [15:0] low_b0_stage, low_b1_stage, low_b2_stage, low_a1_stage, low_a2_stage;
    logic signed [15:0] mid_b0_stage, mid_b1_stage, mid_b2_stage, mid_a1_stage, mid_a2_stage;
    logic signed [15:0] high_b0_stage, high_b1_stage, high_b2_stage, high_a1_stage, high_a2_stage;

    // One-update-per-frame lock
    logic update_pending;
    logic busy;

    // ======================
    // MAIN LOGIC
    // ======================

    always_ff @(posedge clk) begin
        if (!reset) begin
            // Reset active coefficients
            low_b0_r  <= 16'sh4000;
            low_b1_r  <= 16'sh0000;
            low_b2_r  <= 16'sh0000;
            low_a1_r  <= 16'sh0000;
            low_a2_r  <= 16'sh0000;

            mid_b0_r  <= 16'sh4000;
            mid_b1_r  <= 16'sh0000;
            mid_b2_r  <= 16'sh0000;
            mid_a1_r  <= 16'sh0000;
            mid_a2_r  <= 16'sh0000;

            high_b0_r <= 16'sh4000;
            high_b1_r <= 16'sh0000;
            high_b2_r <= 16'sh0000;
            high_a1_r <= 16'sh0000;
            high_a2_r <= 16'sh0000;

            // Reset staged
            low_b0_stage  <= 16'sh4000;
            low_b1_stage  <= 16'sh0000;
            low_b2_stage  <= 16'sh0000;
            low_a1_stage  <= 16'sh0000;
            low_a2_stage  <= 16'sh0000;

            mid_b0_stage  <= 16'sh4000;
            mid_b1_stage  <= 16'sh0000;
            mid_b2_stage  <= 16'sh0000;
            mid_a1_stage  <= 16'sh0000;
            mid_a2_stage  <= 16'sh0000;

            high_b0_stage <= 16'sh4000;
            high_b1_stage <= 16'sh0000;
            high_b2_stage <= 16'sh0000;
            high_a1_stage <= 16'sh0000;
            high_a2_stage <= 16'sh0000;

            update_pending <= 1'b0;
            busy <= 1'b0;
        end 
        else begin

            // ==================================================
            // 1) CAPTURE SPI UPDATE IMMEDIATELY (but only once)
            // ==================================================
            if (update_en && !busy) begin
                // Stage new coefficients
                low_b0_stage <= data[239:224];
                low_b1_stage <= data[223:208];
                low_b2_stage <= data[207:192];
                low_a1_stage <= data[191:176];
                low_a2_stage <= data[175:160];

                mid_b0_stage <= data[159:144];
                mid_b1_stage <= data[143:128];
                mid_b2_stage <= data[127:112];
                mid_a1_stage <= data[111:96];
                mid_a2_stage <= data[95:80];

                high_b0_stage <= data[79:64];
                high_b1_stage <= data[63:48];
                high_b2_stage <= data[47:32];
                high_a1_stage <= data[31:16];
                high_a2_stage <= data[15:0];

                update_pending <= 1'b1;
                busy <= 1'b1;   // lock until commit
            end

            // ==================================================
            // 2) COMMIT AT A SAFE SAMPLE BOUNDARY
            // ==================================================
            if (output_ready && update_pending) begin
                // Commit to ACTIVE coefficients
                low_b0_r  <= low_b0_stage;
                low_b1_r  <= low_b1_stage;
                low_b2_r  <= low_b2_stage;
                low_a1_r  <= low_a1_stage;
                low_a2_r  <= low_a2_stage;

                mid_b0_r  <= mid_b0_stage;
                mid_b1_r  <= mid_b1_stage;
                mid_b2_r  <= mid_b2_stage;
                mid_a1_r  <= mid_a1_stage;
                mid_a2_r  <= mid_a2_stage;

                high_b0_r <= high_b0_stage;
                high_b1_r <= high_b1_stage;
                high_b2_r <= high_b2_stage;
                high_a1_r <= high_a1_stage;
                high_a2_r <= high_a2_stage;

                update_pending <= 1'b0;
                busy <= 1'b0;  // ready for next SPI frame
            end
        end
    end

endmodule
