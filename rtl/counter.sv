// Counter kecil untuk belajar reset, enable, dan penahanan nilai.
// count bertambah satu pada tepi clock saat enable=1; rst_n rendah
// mengosongkannya. Modul ini bukan bagian datapath kriptografi.
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
