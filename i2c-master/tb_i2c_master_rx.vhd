LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_i2c_master_rx IS
END tb_i2c_master_rx;

ARCHITECTURE behavioral OF tb_i2c_master_rx IS

    COMPONENT i2c_master_rx IS
        GENERIC (
            CLK_DIV : INTEGER := 25
        );
        PORT (
            i_clk : IN std_logic;
            i_rst_n : IN std_logic;
            i_i2c_rx_start : IN std_logic;
            i_SDA : IN std_logic;

            o_data : OUT std_logic_vector(7 DOWNTO 0);
            o_i2c_rx_ack : OUT std_logic;
            o_i2c_rx_end : OUT std_logic;
            o_i2c_rx_busy : OUT std_logic;
            o_SCL : OUT std_logic
        );
    END COMPONENT;

    CONSTANT CLK_DIV : INTEGER := 25;

    SIGNAL i_clk : std_logic := '0';
    SIGNAL i_rst_n : std_logic;
    SIGNAL i_i2c_rx_start : std_logic;
    SIGNAL i_SDA : std_logic;

    SIGNAL o_data : std_logic_vector(7 DOWNTO 0);
    SIGNAL o_i2c_rx_ack : std_logic;
    SIGNAL o_i2c_rx_end : std_logic;
    SIGNAL o_i2c_rx_busy : std_logic;
    SIGNAL o_SCL : std_logic;

    SIGNAL test_signal_rx : std_logic_vector(7 DOWNTO 0);
    SIGNAL receiving_byte : std_logic;
    SIGNAL bit_count : INTEGER RANGE 0 TO 7;
    SIGNAL bit_clock_ticks : INTEGER RANGE 0 TO 100;

BEGIN
    -- clock frequency and reset

    i_clk <= NOT i_clk AFTER 10 ns;
    i_rst_n <= '0', '1' AFTER 163 ns;

    u_i2c_master_rx : i2c_master_rx
    GENERIC MAP(
        CLK_DIV => CLK_DIV
    )
    PORT MAP(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_i2c_rx_start => i_i2c_rx_start,
        o_data => o_data,
        o_i2c_rx_ack => o_i2c_rx_ack,
        o_i2c_rx_end => o_i2c_rx_end,
        o_i2c_rx_busy => o_i2c_rx_busy,
        i_SDA => i_SDA,
        o_SCL => o_SCL
    );

    i2c_master_rx_byte : PROCESS (i_clk, i_rst_n)

        VARIABLE test_vector_rx : INTEGER RANGE 0 TO 255;
        VARIABLE system_clock_ticks : INTEGER RANGE 0 TO 1500;
    BEGIN
        IF (i_rst_n = '0') THEN
            test_vector_rx := 255;
            test_signal_rx <= std_logic_vector(to_unsigned(test_vector_rx, 8));
            i_SDA <= '1';
            i_i2c_rx_start <= '0';
            receiving_byte <= '0';
            system_clock_ticks := 0;
            bit_clock_ticks <= 0;
            bit_count <= 0;
        ELSIF (rising_edge(i_clk)) THEN
            system_clock_ticks := system_clock_ticks + 1;
            IF (o_i2c_rx_busy = '0') THEN
                i_SDA <= '1';
                test_signal_rx <= std_logic_vector(to_unsigned(test_vector_rx, 8));
                bit_clock_ticks <= 0;
                bit_count <= 0;
                receiving_byte <= '0';
                IF (system_clock_ticks = 200) THEN
                    i_i2c_rx_start <= '1';
                ELSIF (system_clock_ticks = 201) THEN
                    i_i2c_rx_start <= '0';
                END IF;
            ELSIF (o_i2c_rx_busy = '1') THEN
                IF (receiving_byte = '1') THEN
                    IF (bit_clock_ticks = 5) THEN
                        i_SDA <= test_signal_rx(7 - bit_count);
                        bit_clock_ticks <= bit_clock_ticks + 1;
                    ELSIF (bit_clock_ticks = 99) THEN
                        bit_clock_ticks <= 0;
                        IF (bit_count = 7) THEN
                            bit_count <= 0;
                            receiving_byte <= '0';
                        ELSE
                            bit_count <= bit_count + 1;
                        END IF;
                    ELSE
                        bit_clock_ticks <= bit_clock_ticks + 1;
                    END IF;
                ELSIF (receiving_byte = '0') THEN
                    IF (system_clock_ticks = 205 AND o_SCL = '0') THEN
                        receiving_byte <= '1';
                    ELSIF (system_clock_ticks = 1025) THEN
                        i_SDA <= '0';
                    ELSIF (system_clock_ticks = 1085) THEN
                        i_SDA <= '1';
                        test_vector_rx := test_vector_rx - 1;
                    ELSIF (o_i2c_rx_end = '1') THEN
                        system_clock_ticks := 0;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS i2c_master_rx_byte;

END behavioral;