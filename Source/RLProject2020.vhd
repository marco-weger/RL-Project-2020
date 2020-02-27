library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;   

entity registry is
  generic (
    N : integer := 8
  ); 
  port ( 
    i : in std_logic_vector(N-1 downto 0);
    o : out std_logic_vector(N-1 downto 0);
    clk, rst : in std_logic
  );
end registry;

architecture Behavioral of registry is
begin
   process(clk, rst)
   begin
     if rst = '1' then 
       o <= (others => '0');
     elsif rising_edge(clk) then
       o <= i;
     end if;
  end process;
end Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;   

entity project_reti_logiche is
  port (
    i_clk : in std_logic;
    i_start : in std_logic;
    i_rst : in std_logic;
    i_data : in std_logic_vector(7 downto 0);
    o_address : out std_logic_vector(15 downto 0);
    o_done : out std_logic;
    o_en : out std_logic;
    o_we : out std_logic;
    o_data : out std_logic_vector (7 downto 0)
      --o_add1        : out std_logic_vector (7 downto 0);
      --o_cc        : out std_logic_vector (2 downto 0)
  );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
  component registry is
    generic (
      N : integer := 8
    ); 
    port ( 
      i : in std_logic_vector(N-1 downto 0);
      o : out std_logic_vector(N-1 downto 0);
      clk, rst : in std_logic
    );
  end component;
  component counter8 is
    port ( 
      o : out std_logic_vector(2 downto 0);
      clk, rst : in std_logic
    );
  end component;
  type state_type is (RST,EN_MEM,GET_ADDR,WZ,WRITEOUT,DONE);
  signal next_state, current_state : state_type;
  signal next_addr, current_addr : std_logic_vector(7 downto 0);
  signal start_count : std_logic := '0';
  signal count : std_logic_vector(2 downto 0);
begin
  REG_ADDR : registry
    generic map(N => 8)
    port map(i => next_addr,o => current_addr,clk => i_clk,rst => i_rst);
  COUNTER : counter8
    port map(o => count,clk => i_clk,rst => start_count);
    
  clock: process(i_clk, i_rst)
  begin
    if i_rst='1' then
      current_state <= RST;
      o_en <= '0';
    elsif rising_edge(i_clk) then
      if i_start = '1' then
        current_state <= next_state;
        if next_state = WRITEOUT then
          o_done <= '0';
          o_we <= '1';
        elsif next_state = DONE then
          o_done <= '1';
          o_we <= '0';
        else
          o_done <= '0';
          o_we <= '0';
        end if;
        o_en <= '1';
      elsif i_start = '0' then
        o_done <= '0';
        o_en <= '0';
        o_we <= '0';
      end if;
    end if;
  end process;
  
  delta: process(current_state,i_data,count,current_addr)
  begin   
    case current_state is
      when RST =>
        start_count <= '0';
        next_state <= EN_MEM;
        o_address <= std_logic_vector(to_unsigned(8, 16));
        o_data <= current_addr;
        next_addr <= current_addr;       
--        o_cc <= count;
--        o_add1 <= current_addr;
      when EN_MEM =>
        start_count <= '0';
        next_state <= GET_ADDR;
        o_address <= std_logic_vector(to_unsigned(8, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when GET_ADDR =>
        start_count <= '1';
        next_state <= WZ;
        o_address <= std_logic_vector(to_unsigned(0, 16));
        o_data <= current_addr;
        next_addr <= i_data;
      when WZ =>
        start_count <= '0';
        if to_integer(unsigned(count)) < 7 then
          if (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) = 0 then
            next_addr <= "1" & count & "0001";
            next_state <= WRITEOUT;
            o_address <= std_logic_vector(to_unsigned(9, 16));
          elsif (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) = 1 then
            next_addr <= "1" & count & "0010";
            next_state <= WRITEOUT;
            o_address <= std_logic_vector(to_unsigned(9, 16));
          elsif (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) = 2 then
            next_addr <= "1" & count & "0100";
            next_state <= WRITEOUT;
            o_address <= std_logic_vector(to_unsigned(9, 16));
          elsif (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) = 3 then
            next_addr <= "1" & count & "1000";
            next_state <= WRITEOUT;
            o_address <= std_logic_vector(to_unsigned(9, 16));
          else
            next_addr <= current_addr;
            next_state <= WZ;
            o_address <= std_logic_vector(to_unsigned(1+to_integer(unsigned(count)), 16));
          end if;
        else
          next_state <= WRITEOUT;
          o_address <= std_logic_vector(to_unsigned(9, 16));
          next_addr <= current_addr;
        end if;
        o_data <= current_addr;
      when WRITEOUT =>
        start_count <= '0';
        next_state <= DONE;
        o_address <= std_logic_vector(to_unsigned(9, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when DONE =>
        start_count <= '0';
        next_state <= RST;
        o_address <= std_logic_vector(to_unsigned(8, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      end case;
  end process;
end Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;   

entity counter8 is
  port ( 
    o : out std_logic_vector(2 downto 0);
    clk, rst : in std_logic
  );
end counter8;

architecture Behavioral of counter8 is
  type state_type is (S0,S1,S2,S3,S4,S5,S6,S7);
  signal next_state, current_state : state_type;
begin
   process(clk, rst)
   begin
     if rst = '1' then
       current_state <= S0;
     elsif rising_edge(clk) then
       current_state <= next_state;
     end if;
  end process;
  
  process(current_state)
  begin
     case current_state is
       when S0 =>
         o <= "000";
         next_state <= S1;
       when S1 =>
         o <= "001";
         next_state <= S2;
       when S2 =>
         o <= "010";
         next_state <= S3;
       when S3 =>
         o <= "011";
         next_state <= S4;
       when S4 =>
         o <= "100";
         next_state <= S5;
       when S5 =>
         o <= "101";
         next_state <= S6;
       when S6 =>
         o <= "110";
         next_state <= S7;
       when S7 =>
         o <= "111";
         next_state <= S7;
       end case;
  end process;
end Behavioral;