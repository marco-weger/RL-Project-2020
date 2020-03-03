package CONSTANTS is
  constant SIZE_MEM : natural := 16;  -- dimensione indirizzo memoria
  constant SIZE_ADDR : natural := 8;  -- dimensione cella memoria
  constant SIZE_WZ : natural := 4;    -- estensione singola WZ
  constant COUNT_WZ : natural := 3;   -- dimensione WZ_NUM
  constant N_WZ : natural := 8;       -- numero WZ
end package CONSTANTS;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use WORK.CONSTANTS.ALL;  
 
entity project_reti_logiche is -- entity fornita da specifica
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
  type state_type is (RST,EN_MEM,GET_ADDR,WZ,W_MEM,DONE); -- stati FSM
  signal next_state, current_state : state_type;
  signal next_addr, current_addr : std_logic_vector(SIZE_ADDR-1 downto 0) := (others => '0'); -- registro ADDR da codificare
  signal start_count : std_logic := '0'; -- reset contatore
  signal count : std_logic_vector(COUNT_WZ-1 downto 0) := (others => '0'); -- segnale output contatore
begin
  c: counter
    generic map(N => COUNT_WZ)
    port map(o => count,clk => i_clk,rst => start_count); -- clock del contatore sincronizzato con il componente
    
  clock: process(i_clk, i_rst)
  begin
    if i_rst='1' then -- reset
      current_state <= RST;
      current_addr <= (others => '0');
      o_en <= '0';
      o_done <= '0';
      o_we <= '0';
    elsif rising_edge(i_clk) then
      if i_start = '1' then -- con start attivo lo stato della macchina "avanza"
        current_state <= next_state;
        current_addr <= next_addr;
        o_en <= '1';
        if next_state = W_MEM then -- stato di scrittura finale, alzo write enable
          o_done <= '0';
          o_we <= '1';
        elsif next_state = DONE then -- stato post scrittura, alzo done
          o_done <= '1';
          o_we <= '0';
        else -- in tutte le altre situazioni sia done che write enable devono restare bassi
          o_done <= '0';
          o_we <= '0';
        end if;
      elsif i_start = '0' then -- quando start viene portato a 0 mi pongo nella situazione iniziale e rimango nello stato attuale
        current_state <= current_state;
        current_addr <= (others => '0');
        o_en <= '0';
        o_done <= '0';
        o_we <= '0';
      end if;
    end if;
  end process;
  
  delta: process(current_state,i_data,count,current_addr) -- FSM
    variable one_hot : std_logic_vector(SIZE_WZ-1 downto 0); -- vettore one hot che indica l'offset nella WZ
  begin   
    case current_state is
      when RST => -- reset e stato di inizio elaborazione
        start_count <= '0';
        next_state <= EN_MEM;
        o_address <= std_logic_vector(to_unsigned(N_WZ, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when EN_MEM => -- la memoria viene abilitata (lo rimarrà fino alla scrittura finale)
        start_count <= '0';
        next_state <= GET_ADDR;
        o_address <= std_logic_vector(to_unsigned(N_WZ, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when GET_ADDR => -- leggo ADDR e mi porto nella cella 0 della RAM
        start_count <= '1';
        next_state <= WZ;
        o_address <= std_logic_vector(to_unsigned(0, 16));
        o_data <= current_addr;
        next_addr <= i_data;
      when WZ => -- leggo l'i-esima WZ e mi porto nella cella i+1 della RAM
        start_count <= '0';
        o_data <= current_addr;
          if (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) >= 0 and
          (to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data))) <= SIZE_WZ-1 and
          to_integer(unsigned(count)) <= N_WZ-1 then -- controllo se ADDR è nella WZ
            one_hot := (others => '0');
            one_hot((to_integer(unsigned(current_addr)) - to_integer(unsigned(i_data)))) := '1';
            next_state <= W_MEM;
            o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
            next_addr <= "1" & count & one_hot;
          elsif to_integer(unsigned(count)) < N_WZ-1 then -- non ho ancora scandito tutte le WZ: prosegui
            next_state <= WZ;
            o_address <= std_logic_vector(to_unsigned(1+to_integer(unsigned(count)), 16));
            next_addr <= current_addr;
          else -- ho scandito tutte le WZ: ADDR non cambia
            next_state <= W_MEM;
            o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
            next_addr <= current_addr;
          end if;
      when W_MEM => -- scrittura dell'indirizzo in RAM
        start_count <= '0';
        next_state <= DONE;
        o_address <= std_logic_vector(to_unsigned(N_WZ+1, 16));
        o_data <= current_addr;
        next_addr <= current_addr;
      when DONE => -- singola operazione completata, mi preparo alla prossima elaborazione
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

entity counter is -- contatore a n bit per scandire le WZ
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