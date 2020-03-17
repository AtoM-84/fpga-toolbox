LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_i2c_master IS
END tb_i2c_master;

ARCHITECTURE rtl OF tb_i2c_master IS

    COMPONENT i2c_master
        GENERIC (
            CLK_DIV : INTEGER := 25;
            N : INTEGER := 6 --Max byte number read/written
        );
        PORT (
            i_clk : IN std_logic; -- system clock
            i_rst : IN std_logic; -- asynhcronous reset signal
            i_i2c_start : IN std_logic; -- start signal (from higher level FSM)
            i_device_address : IN std_logic_vector(6 DOWNTO 0); -- device address evaluated when rising_edge on i_i2c_start signal
            i_read_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0); -- number of bytes to be read/evaluated when rising_edge on i_i2c_start signal
            i_write_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0); --number of bytes to be written/when rising_edge on i_i2c_start signal
            i_RW : IN std_logic; -- Conventions are read = 1, write = 0 from I2C conventions/when rising_edge on i_i2c_start signal
            i_data : IN std_logic_vector(7 DOWNTO 0); -- data input to i2c assessed when rising_edge on o_data_access/to be updated after each o_data_access event
            i_SDA : IN std_logic; -- serial data from slave - same pin as o_sda

            o_busy : OUT std_logic; -- busy signal when i2c-master is out of idle state
            o_error : OUT std_logic; -- error signal (acknowledgment not received)
            o_data_access : OUT std_logic; -- data access signal to evaluate i_data
            o_data_ready : OUT std_logic; -- data ready to signal when new data available at o_data
            o_data : OUT std_logic_vector(7 DOWNTO 0); -- data out from i2c to assess when data_ready is high
            o_i2c_end : OUT std_logic; -- end of transmission signal
            o_SCL : OUT std_logic; -- serial clock from master - default to HIGH
            o_SDA : OUT std_logic -- serial data from master - same pin as i_sda
        );
    END COMPONENT;

    CONSTANT CLK_DIV : INTEGER := 100;
    CONSTANT N : INTEGER := 8;

    SIGNAL i_clk : std_logic := '0';
    SIGNAL i_rst : std_logic;
    SIGNAL i_i2c_start : IN std_logic;
    SIGNAL i_device_address : IN std_logic_vector(6 DOWNTO 0);
    SIGNAL i_read_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL i_write_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL i_RW : IN std_logic;
    SIGNAL i_data : IN std_logic_vector(7 DOWNTO 0);

    SIGNAL o_busy : OUT std_logic;
    SIGNAL o_error : OUT std_logic;
    SIGNAL o_data_access : OUT std_logic;
    SIGNAL o_data_ready : OUT std_logic;
    SIGNAL o_data : OUT std_logic_vector(7 DOWNTO 0);
    SIGNAL o_i2c_end : OUT std_logic;

    SIGNAL o_SCL : OUT std_logic;
    SIGNAL i_SDA : IN std_logic;
    SIGNAL o_SDA : OUT std_logic;

    SIGNAL master_to_slave_test_vector : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL slave_to_master_test_vector : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL SCL_counter : INTEGER;
    SIGNAL count_fall : INTEGER;

BEGIN

    i_clk <= NOT i_clk AFTER 5 ns; -- 100MHz simulated clock
    i_rst <= '0', '1' AFTER 163 ns;
    u_i2c_master : i2c_master
    GENERIC MAP(
        N => N,
        CLK_DIV => CLK_DIV)
    PORT MAP(
        i_clk => i_clk,
        i_rst => i_rst,
        i_i2c_start => i_i2c_start,
        o_i2c_end => o_i2c_end,
        o_SCL => o_SCL,
        i_SDA => i_SDA,
        o_SDA => o_SDA,
        i_device_address => i_device_address,
        i_RW => i_RW,
        i_read_byte_nb => i_read_byte_nb,
        i_write_byte_nb => i_write_byte_nb,
        i_data => i_data,
        o_data => o_data,
        o_busy => o_busy,
        o_error => o_error,
        o_data_access => o_data_access,
        o_data_ready => o_data_ready
    );

END behavioral;