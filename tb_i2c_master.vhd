LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_i2c_master IS
END tb_i2c_master;

ARCHITECTURE behavioral OF tb_i2c_master IS

    COMPONENT i2c_master
        GENERIC (
            CLK_DIV : INTEGER := 25;
            N : INTEGER := 6 --Max byte number read/written
        );
        PORT (
            i_clk : IN std_logic; -- system clock
            i_rstb : IN std_logic; -- asynhcronous reset signal
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
    SIGNAL i_rstb : std_logic;
    SIGNAL i_i2c_start : std_logic;
    SIGNAL i_device_address : std_logic_vector(6 DOWNTO 0);
    SIGNAL i_read_byte_nb : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL i_write_byte_nb : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL i_RW : std_logic;
    SIGNAL i_data : std_logic_vector(7 DOWNTO 0);

    SIGNAL o_busy : std_logic;
    SIGNAL o_error : std_logic;
    SIGNAL o_data_access : std_logic;
    SIGNAL o_data_ready : std_logic;
    SIGNAL o_data : std_logic_vector(7 DOWNTO 0);
    SIGNAL o_i2c_end : std_logic;

    SIGNAL o_SCL : std_logic;
    SIGNAL i_SDA : std_logic;
    SIGNAL o_SDA : std_logic;

    SIGNAL master_to_slave_test_vector : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL slave_to_master_test_vector : std_logic_vector(N - 1 DOWNTO 0);
    SIGNAL SCL_counter : INTEGER;

BEGIN

    i_clk <= NOT i_clk AFTER 5 ns; -- 100MHz simulated clock
    i_rstb <= '0', '1' AFTER 163 ns;
    u_i2c_master : i2c_master
    GENERIC MAP(
        N => N,
        CLK_DIV => CLK_DIV)
    PORT MAP(
        i_clk => i_clk,
        i_rstb => i_rstb,
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

    p_control : PROCESS (i_clk, i_rstb)
        VARIABLE v_control : unsigned(7 DOWNTO 0); -- !!!!! Valeur à modifier
    BEGIN
        IF (i_rstb = '0') THEN
            v_control := (OTHERS => '0');
            i_i2c_start <= '0';
            i_device_address <= std_logic_vector(to_unsigned(16#5F#, 7)); -- address is device #95
            i_RW <= '1'; -- read moder
            i_write_byte_nb <= std_logic_vector(to_unsigned(255,8)); -- 256 octets à écrire
            i_read_byte_nb <= std_logic_vector(to_unsigned(255,8)); -- 256 octets à lire
            master_to_slave_test_vector <= (OTHERS => '0');
        ELSIF (rising_edge(i_clk)) THEN
        -- action dans cette boucle : lancer le start, sur data access incrémenter le test vector et attendre en sortie pour produire un acknowledgment
            v_control := v_control + 1; -- !!!!! Valeur à modifier
            IF (v_control = 10) THEN -- !!!!! Valeur à modifier
                i_i2c_start <= '1';
            ELSE
                i_i2c_start <= '0';
            END IF;
            if (o_data_access = '1') then
                master_to_slave_test_vector <= std_logic_vector(unsigned(master_to_slave_test_vector) + 1);
            end if ;
        END IF;
    END PROCESS p_control;

END behavioral;