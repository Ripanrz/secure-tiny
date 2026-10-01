// Small learning block used before the cryptographic RTL milestones.
module counter #(
    parameter int unsigned WIDTH = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    output logic [WIDTH-1:0]      count
);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count <= '0;
        end else if (enable) begin
            count <= count + 1'b1;
        end
    end

endmodule
