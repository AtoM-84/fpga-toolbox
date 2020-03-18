LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_i2c_master_tx IS
END tb_i2c_master_tx;

ARCHITECTURE behavioral OF tb_i2c_master_tx IS

    COMPONENT i2c_master_tx IS
        GENERIC (
            CLK_DIV : INTEGER := 25;
            N : INTEGER := 6
        );
        PORT (
            i_clk : IN std_logic;
            i_rst_n : IN std_logic;
            i_i2c_tx_start : IN std_logic;
            i_data : IN std_logic_vector(7 DOWNTO 0);
            i_SDA : IN std_logic;

            o_i2c_tx_ack : OUT std_logic;
            o_i2c_tx_end : OUT std_logic;
            o_i2c_tx_busy : OUT std_logic;
            o_SDA : OUT std_logic;
            o_SCL : OUT std_logic
        );
    END COMPONENT;

    CONSTANT CLK_DIV : INTEGER := 25;
    CONSTANT N : INTEGER := 6;

    SIGNAL i_clk : std_logic := '0';
    SIGNAL i_rst_n : std_logic;
    SIGNAL i_i2c_tx_start : std_logic;
    SIGNAL i_data : std_logic_vector(7 DOWNTO 0);

    SIGNAL o_i2c_tx_ack : std_logic;
    SIGNAL o_i2c_tx_end : std_logic;
    SIGNAL o_i2c_tx_busy : std_logic;

    SIGNAL i_SDA : std_logic;
    SIGNAL o_SDA : std_logic;
    SIGNAL o_SCL : std_logic;

    SIGNAL test_signal_tx : std_logic_vector(7 DOWNTO 0);

BEGIN
    -- clock frequency and reset

    i_clk <= NOT i_clk AFTER 10 ns;
    i_rst_n <= '0', '1' AFTER 163 ns;

    -- port and constant mapping

    u_i2c_master_tx : i2c_master_tx
    GENERIC MAP(
        CLK_DIV => CLK_DIV,
        N => N
    )
    PORT MAP(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_i2c_tx_start => i_i2c_tx_start,
        i_data => i_data,
        o_i2c_tx_ack => o_i2c_tx_ack,
        o_i2c_tx_end => o_i2c_tx_end,
        o_i2c_tx_busy => o_i2c_tx_busy,
        i_SDA => i_SDA,
        o_SDA => o_SDA,
        o_SCL => o_SCL
    );

    i2c_master_tx_test : PROCESS (i_clk, i_rst_n)

        VARIABLE test_vector_tx : INTEGER RANGE 0 TO 255;
        VARIABLE counter_for_ack : INTEGER RANGE 0 TO 1500;

    BEGIN
        IF (i_rst_n = '0') THEN
            test_vector_tx := 0;
            test_signal_tx <= std_logic_vector(to_unsigned(test_vector_tx, 8));
            counter_for_ack := 0;
            i_SDA <= '1';
            i_i2c_tx_start <= '0';
        ELSIF (rising_edge(i_clk)) THEN
            IF (o_i2c_tx_busy = '0' AND counter_for_ack = 500) THEN
                i_data <= test_signal_tx;
                i_SDA <= '1';
                i_i2c_tx_start <= '1';
                counter_for_ack := counter_for_ack + 1;
            ELSIF (o_i2c_tx_busy = '0' AND counter_for_ack = 501) THEN
                i_i2c_tx_start <= '0';
            ELSIF (o_i2c_tx_busy = '1' AND o_i2c_tx_end = '1') THEN
                test_vector_tx := test_vector_tx + 1;
                test_signal_tx <= std_logic_vector(to_unsigned(test_vector_tx, 8));
            ELSIF (o_i2c_tx_busy = '1') THEN
                test_signal_tx <= test_signal_tx;
                i_i2c_tx_start <= '0';
                counter_for_ack := counter_for_ack + 1;
                IF (counter_for_ack = 1325) THEN
                    i_SDA <= '0';
                ELSIF (counter_for_ack = 1375) THEN
                    i_SDA <= '1';
                    counter_for_ack := 0;
                END IF;
                else
                counter_for_ack := counter_for_ack + 1;
            END IF;
        END IF;

    END PROCESS i2c_master_tx_test;

END behavioral;