package CONSTANTS is
  constant SIZE_MEM : natural := 16;
  constant SIZE_ADDR : natural := 8;
  constant SIZE_WZ : natural := 4;
  constant COUNT_WZ : natural := 3;
  constant N_WZ : natural := 8;
end package CONSTANTS;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use WORK.CONSTANTS.ALL;  
 
entity project_reti_logiche is
  port (
    i_clk : in std_logic;
    i_start : in std_logic;
    i_rst : in std_logic;
    i_data : in std_logic_vector(SIZE_ADDR-1 downto 0);
    o_address : out std_logic_vector(SIZE_MEM-1 downto 0);
    o_done : out std_logic;
    o_en : out std_logic;
    o_we : out std_logic;
    o_data : out std_logic_vector (SIZE_ADDR-1 downto 0)
  );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
  component counter is
    generic(N : integer);
    port(
      o : out std_logic_vector(N-1 downto 0);
      clk, rst : in std_logic
    );
  end component;
  type state_type is (RST,MEM,ADDR,WZ,WRITE,DONE);
  signal next_state, current_state : state_type;
  signal next_addr, current_addr : std_logic_vector(SIZE_ADDR-1 downto 0) := (others => '0');
  signal start_count : std_logic := '0';
  signal count : std_logic_vector(COUNT_WZ-1 downto 0) := (others => '0');
begin
  c: counter
    generic map(N => COUNT_WZ)
    port map(o => count,clk => i_clk,rst => start_count);
    
  clock: process(i_clk, i_rst)
  begin
    if i_rst='1' then
      current_state <= RST;
      current_addr <= (others => '0');
      o_en <= '0';
      o_done <= '0';
      o_we <= '0';
    elsif rising_edge(i_clk) then
      if i_start = '1' then
        current_state <= next_state;
        current_addr <= next_addr;
        o_en <= '1';
        if next_state = MEM then
          o_done <= '0';
          o_we <= '1';
        elsif next_state = DONE then
          o_done <= '1';
          o_we <= '0';
        else
          o_done <= '0';
          o_we <= '0';
        end if;
      elsif i_start = '0' then
        current_state <= current_state;
        current_addr <= (others => '0');
        o_en <= '0';
        o_done <= '0';
        o_we <= '0';
      end if;
    end if;
  end process;
  
  delta: process(current_state,i_data,count,current_addr)
    variable one_hot : std_logic_vector(SIZE_WZ-1 downto 0);
  begin   
    case current_state is
      when RST =>
        start_count <= '0';
        next_state <= MEM;
        o_address <= std_logic_vector(to_unsigned(N_WZ, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when MEM =>
        start_count <= '0';
        next_state <= ADDR;
        o_address <= std_logic_vector(to_unsigned(N_WZ, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when ADDR =>
        start_count <= '1';
        next_state <= WZ;
        o_address <= std_logic_vector(to_unsigned(0, 16));
        o_data <= current_addr;
        next_addr <= i_data;
      when WZ =>
        start_count <= '0';
        o_data <= current_addr;
          if (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) >= 0 and
          (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) <= SIZE_WZ-1 and
          to_integer(unsigned(count)) <= N_WZ-1 then
            one_hot := (others => '0');
            one_hot((to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data)))) := '1';
            next_state <= MEM;
            o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
            next_addr <= "1" & count & one_hot;
          elsif to_integer(unsigned(count)) < N_WZ-1 then
            next_state <= WZ;
            o_address <= std_logic_vector(to_unsigned(1+to_integer(unsigned(count)), 16));
            next_addr <= current_addr;
          else
            next_state <= MEM;
            o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
            next_addr <= current_addr;
          end if;
      when MEM =>
        start_count <= '0';
        next_state <= DONE;
        o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when DONE =>
        start_count <= '0';
        next_state <= RST;
        o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      end case;
  end process;
end Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all; 

entity counter is
  generic(N : integer);
  port(
    o : out std_logic_vector(N-1 downto 0);
    clk, rst : in std_logic
  );
end counter;

architecture counter of counter is
  signal count : std_logic_vector(N-1 downto 0);
begin
  process(clk,rst)
  begin
    if rst = '1' then
      count <= (others => '0');
    elsif rising_edge(clk) then
      count <= count + 1;
    end if;
  end process;
  
  o <= count;
end counter;