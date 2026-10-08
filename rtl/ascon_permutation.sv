// Permutasi Ascon iteratif, yaitu blok inti yang mencampur state 320-bit.
// Port: start/rounds/state_in memulai kerja; busy/done/error memberi status;
// state_out menahan hasil akhir. Satu ronde dihitung tiap siklus aktif agar
// logika ronde dipakai ulang. Susunan state S0||S1||S2||S3||S4 serta rumus
// dan konstanta mengikuti NIST SP 800-232 Bagian 3.
module ascon_permutation (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [4:0]   rounds,       // Valid range: 1 through 16.
    input  logic [319:0] state_in,
    output logic         busy,
    output logic         done,
    output logic         error,
    output logic [319:0] state_out
);

    typedef enum logic {IDLE, RUN} state_t;
    state_t state;

    logic [319:0] state_reg;
    logic [4:0] rounds_latched;
    logic [4:0] round_index;
    logic [4:0] constant_index;
    logic [319:0] state_after_round;

    function automatic logic [63:0] rotate_right64(
        input logic [63:0] value,
        input integer amount
    );
        // Rotasi 64-bit digunakan pada lapisan difusi linear setiap ronde.
        rotate_right64 = (value >> amount) | (value << (64 - amount));
    endfunction

    function automatic logic [63:0] round_constant(input logic [4:0] index);
        begin
            // Tabel konstanta SP 800-232. Pemanggil memilih ekor tabel sesuai
            // banyaknya ronde (p12 memakai indeks 4 sampai 15).
            case (index)
                5'd0:  round_constant = 64'h000000000000003c;
                5'd1:  round_constant = 64'h000000000000002d;
                5'd2:  round_constant = 64'h000000000000001e;
                5'd3:  round_constant = 64'h000000000000000f;
                5'd4:  round_constant = 64'h00000000000000f0;
                5'd5:  round_constant = 64'h00000000000000e1;
                5'd6:  round_constant = 64'h00000000000000d2;
                5'd7:  round_constant = 64'h00000000000000c3;
                5'd8:  round_constant = 64'h00000000000000b4;
                5'd9:  round_constant = 64'h00000000000000a5;
                5'd10: round_constant = 64'h0000000000000096;
                5'd11: round_constant = 64'h0000000000000087;
                5'd12: round_constant = 64'h0000000000000078;
                5'd13: round_constant = 64'h0000000000000069;
                5'd14: round_constant = 64'h000000000000005a;
                5'd15: round_constant = 64'h000000000000004b;
                default: round_constant = 64'b0;
            endcase
        end
    endfunction

    function automatic logic [319:0] ascon_round(
        input logic [319:0] input_state,
        input logic [63:0] constant_value
    );
        logic [63:0] x0, x1, x2, x3, x4;
        logic [63:0] y0, y1, y2, y3, y4;
        begin
            // Pecah state menjadi lima word; konstanta ronde di-XOR ke x2.
            x0 = input_state[319:256];
            x1 = input_state[255:192];
            x2 = input_state[191:128] ^ constant_value;
            x3 = input_state[127:64];
            x4 = input_state[63:0];

            // Lapisan nonlinear: 64 salinan S-box 5-bit bekerja paralel,
            // masing-masing pada bit-slice yang sama dari kelima word.
            y0 = (x4 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ (x1 & x0) ^ x1 ^ x0;
            y1 = x4 ^ (x3 & x2) ^ (x3 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ x1 ^ x0;
            // Nilai 1 pada persamaan S-box menjadi mask 64-bit semua satu.
            y2 = (x4 & x3) ^ x4 ^ x2 ^ x1 ^ 64'hffffffffffffffff;
            y3 = (x4 & x0) ^ x4 ^ (x3 & x0) ^ x3 ^ x2 ^ x1 ^ x0;
            y4 = (x4 & x1) ^ x4 ^ x3 ^ (x1 & x0) ^ x1;

            ascon_round = {
                y0 ^ rotate_right64(y0, 19) ^ rotate_right64(y0, 28),
                y1 ^ rotate_right64(y1, 61) ^ rotate_right64(y1, 39),
                y2 ^ rotate_right64(y2, 1)  ^ rotate_right64(y2, 6),
                y3 ^ rotate_right64(y3, 10) ^ rotate_right64(y3, 17),
                y4 ^ rotate_right64(y4, 7)  ^ rotate_right64(y4, 41)
            };
        end
    endfunction

    // Pilih konstanta ronde aktif dan hitung kandidat state berikutnya.
    always_comb begin
        constant_index = 5'd16 - rounds_latched + round_index;
        state_after_round = ascon_round(state_reg, round_constant(constant_index));
    end

    // FSM dua keadaan: IDLE menangkap permintaan; RUN menyimpan hasil satu
    // ronde per clock sampai jumlah ronde yang diminta selesai.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            state_reg <= '0;
            rounds_latched <= '0;
            round_index <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            state_out <= '0;
        end else begin
            done <= 1'b0;
            error <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        if ((rounds >= 5'd1) && (rounds <= 5'd16)) begin
                            state_reg <= state_in;
                            rounds_latched <= rounds;
                            round_index <= 5'd0;
                            busy <= 1'b1;
                            state <= RUN;
                        end else begin
                            done <= 1'b1;
                            error <= 1'b1;
                        end
                    end
                end

                RUN: begin
                    state_reg <= state_after_round;
                    if (round_index == rounds_latched - 5'd1) begin
                        state_out <= state_after_round;
                        state <= IDLE;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        round_index <= round_index + 5'd1;
                        busy <= 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    error <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
