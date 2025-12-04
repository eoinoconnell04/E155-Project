module control(
    input  logic              clk,
    input  logic              reset,        // active high
    input  logic              update_en,    // pulse from spi_valid_sync
    input  logic [335:0]      data,

    // Low-pass filter coefficients
    output logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2,

    // Mid-pass
    output logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2,

    // High-pass
    output logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2
);

    // Internal registers for stable coefficient storage
    logic signed [15:0] low_b0_r, low_b1_r, low_b2_r, low_a1_r, low_a2_r;
    logic signed [15:0] mid_b0_r, mid_b1_r, mid_b2_r, mid_a1_r, mid_a2_r;
    logic signed [15:0] high_b0_r, high_b1_r, high_b2_r, high_a1_r, high_a2_r;

    // Assign to outputs
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

    // Synchronous coefficient update
    always_ff @(posedge clk) begin
        if (reset==0) begin
            // You can choose defaults here:
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

        end else if (update_en) begin
            // Extract Low-pass coefficients
            low_b0_r <= data[239:224];
            low_b1_r <= data[223:208];
            low_b2_r <= data[207:192];
            low_a1_r <= data[191:176];
            low_a2_r <= data[175:160];

            // Extract Mid-pass coefficients
            mid_b0_r <= data[159:144];
            mid_b1_r <= data[143:128];
            mid_b2_r <= data[127:112];
            mid_a1_r <= data[111:96];
            mid_a2_r <= data[95:80];

            // Extract High-pass coefficients
            high_b0_r <= data[79:64];
            high_b1_r <= data[63:48];
            high_b2_r <= data[47:32];
            high_a1_r <= data[31:16];
            high_a2_r <= data[15:0];
        end
    end

endmodule
