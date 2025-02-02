library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;

entity top_sdram is
    generic (
	C_arch: natural := ARCH_MI32;
	C_clk_freq: natural := 80
    );
    port (
	clk_25m: in std_logic;

	-- SDRAM
	sdram_clk: out std_logic;
	sdram_cke: out std_logic;
	sdram_csn: out std_logic;
	sdram_rasn: out std_logic;
	sdram_casn: out std_logic;
	sdram_wen: out std_logic;
	sdram_a: out std_logic_vector (12 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_d: inout std_logic_vector (15 downto 0);

	-- On-board simple IO
	led: out std_logic_vector(7 downto 0);
	btn_pwr, btn_f1, btn_f2: in std_logic;
	btn_up, btn_down, btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0);

	-- GPIO
	gp: inout std_logic_vector(27 downto 0);
	gn: inout std_logic_vector(27 downto 0);

	-- Audio jack 3.5mm
	p_tip: inout std_logic_vector(3 downto 0);
	p_ring: inout std_logic_vector(3 downto 0);
	p_ring2: inout std_logic_vector(3 downto 0);

	-- SIO0 (FTDI)
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;

	-- Digital Video (differential outputs)
	gpdi_dp, gpdi_dn: out std_logic_vector(3 downto 0);
  
	-- i2c shared for digital video and RTC
	gpdi_scl, gpdi_sda: inout std_logic;

	-- SPI flash
	flash_so: in std_logic;
	flash_si: out std_logic;
	flash_cen: out std_logic;
	--flash_sck: out std_logic; -- accessed via special ECP5 primitive
	flash_holdn, flash_wpn: out std_logic := '1';

	-- ADC MAX11123
	adc_csn: out std_logic;
	adc_sclk: out std_logic;
	adc_mosi: out std_logic;
	adc_miso: in std_logic;

	-- PCB antenna
	ant: out std_logic;

	-- '1' = power off
	shutdown: out std_logic := '0'
    );
end top_sdram;

architecture x of top_sdram is
    signal clk, pll_lock: std_logic;
    signal clk_133m, clk_66m, clk_160m, clk_80m: std_logic;
    signal reset: std_logic;
    signal sio_break: std_logic;

    signal R_simple_in: std_logic_vector(19 downto 0);

begin
    I_top: entity work.glue_sdram_min
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_spi => 2,
	C_simple_out => 8,
	C_simple_in => 20,
	C_debug => false
    )
    port map (
	clk => clk,
	reset => reset,
	sdram_clk => sdram_clk,
	sdram_cke => sdram_cke,
	sdram_cs => sdram_csn,
	sdram_we => sdram_wen,
	sdram_ba => sdram_ba,
	sdram_dqm => sdram_dqm,
	sdram_ras => sdram_rasn,
	sdram_cas => sdram_casn,
	sdram_addr => sdram_a,
	sdram_data => sdram_d,
	sio_rxd(0) => rs232_rx,
	sio_txd(0) => rs232_tx,
	sio_break(0) => sio_break,
	simple_in => R_simple_in,
	simple_out => led
    );
    R_simple_in <= sw & x"00" & '0' & not btn_pwr & btn_f2 & btn_f1
      & btn_up & btn_down & btn_left & btn_right when rising_edge(clk);

    I_pll: entity work.pll
    port map (
	clki => clk_25m,
	stdby => '0',
	enclk_133m => '1',
	enclk_66m => '1',
	enclk_160m => '1',
	enclk_80m => '1',
	clk_133m => clk_133m,
	clk_66m => clk_66m,
	clk_160m => clk_160m,
	clk_80m => clk_80m,
	lock => pll_lock 
    );

    clk <= clk_160m when C_clk_freq = 160
      else clk_133m when C_clk_freq = 133
      else clk_80m when C_clk_freq = 80
      else clk_66m;
    reset <= not pll_lock or sio_break;
end x;
