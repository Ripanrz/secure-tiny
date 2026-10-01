// Holds the final tag until the consumer accepts it.
module tag_generator (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         load,
    input  logic [127:0] tag_in,
    output logic         tag_valid,
    input  logic         tag_ready,
    output logic [127:0] tag_out
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tag_valid <= 1'b0;
            tag_out <= '0;
        end else begin
            if (tag_valid && tag_ready)
                tag_valid <= 1'b0;

            if (load && (!tag_valid || tag_ready)) begin
                tag_out <= tag_in;
                tag_valid <= 1'b1;
            end
        end
    end
endmodule
