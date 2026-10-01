create_clock -name FPGA_CLK1_50 -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
