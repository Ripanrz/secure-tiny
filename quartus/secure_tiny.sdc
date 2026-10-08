# Constraint clock 50 MHz dari FPGA_CLK1_50 (periode 20 ns).
# Port transaksi virtual belum memiliki input/output delay fisik.
create_clock -name FPGA_CLK1_50 -period 20.000 [get_ports {clk}]
# Tambahkan ketidakpastian clock turunan untuk analisis setup/hold internal.
derive_clock_uncertainty
