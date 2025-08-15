module safecrack_fsm (
    input  logic       clk,            // clock
    input  logic       rst,            // reset
    input  logic       ms,             // mudança de senha 
    input  logic [3:0] btn,            // buttons inputs (BTN[3:0])
    output logic       unlocked,       // output: 1 quando o cofre é destravado
    output logic [2:0] leds_erros,     // output: 1 quando tiver errado
    output logic [2:0] leds_acertos,   // output: 1 quando tiver acertado
    output logic [9:0] leds_segundos   // output: 1 enquanto contar os segundos
);

    // one-hot encoding | criação de estados
    typedef enum logic [8:0] { 
        S0   = 9'b0_0000_0001,   // estado inicial
        S1   = 9'b0_0000_0010,   // BTN = 1 right
        S2   = 9'b0_0000_0100,   // BTN = 2 right
        S3   = 9'b0_0000_1000,   // BTN = 3 right → unlock
        MS0  = 9'b0_0001_0000,   // mudança de senha: captura 1º botão
        MS1  = 9'b0_0010_0000,   // mudança de senha: captura 2º botão
        MS2  = 9'b0_0100_0000,   // mudança de senha: captura 3º botão → volta S0
        ERRO = 9'b0_1000_0000,   // errando tentativa de senha
        CONT = 9'b1_0000_0000    // sistema travado → inicia-se o contador de 10s
    } state_t;

    state_t state, next;           // state pode assumir valores do typedef
    state_t state_before_error;    // guarda o estado antes do erro para voltar a ele
	 state_t state_wait_release;    // guarda o estado antes do erro para voltar a ele

    logic [3:0] passcode[2:0]='{0: 4'b1110, 1: 4'b1101, 2: 4'b1011};
    logic [1:0] qtd_erros = 2'b00;        // armazena a quantidade de erros (zerada no reset)
    logic [1:0] qtd_acertos = 2'b00;      // armazena a quantidade de acertos (zerada no reset)
    logic [3:0] segundos = 4'd0;          // contador de segundos no bloqueio (0–10)
    logic [1:0] ms_index = 2'd0;          // índice para mudança de senha
	 logic [25:0] div_count = 26'd0; 		// 26 bits conseguem contar até 67 milhões
	 logic        one_hz = 1'b0;           // pulso de 1 Hz
	 logic [3:0] last_btn_pressed;
		 
		
	 // Reset assíncrono só no estado
	 always_ff @(posedge clk or posedge rst) begin
		 if (rst) begin
			  state <= S0;
			  state_before_error <= S0;  // estado inicial antes de erro
			  state_wait_release <= S0;
		 end else begin
			  if (next == ERRO && state != ERRO) begin
					state_before_error <= state;
			  end
		     if (state == S3) begin
					state_before_error <= S0;  // estado inicial antes de erro
			  end
			  if (btn != 4'b1111 && next != state && next != ERRO) begin
					// calcula próximo estado esperado com base no estado atual e botão pressionado
					case (state)
						  S0: state_wait_release <= (btn == passcode[0]) ? S1 : S0;
						  S1: state_wait_release <= (btn == passcode[1]) ? S2 : S1;
						  S2: state_wait_release <= (btn == passcode[2]) ? S3 : S2;
						  MS0: state_wait_release <= MS0;
						  MS1: state_wait_release <= MS1;
						  MS2: state_wait_release <= MS2;
						  default: state_wait_release <= state; 
					endcase
					last_btn_pressed <= btn; // guarda o botão pressionado
			  end
			  state <= next;
		 end
	 end
	 
    // transição de estado e registradores (de acordo com o clock)
    always_ff @(posedge clk) begin   
		if (rst) begin
			  passcode[0] <= 4'b1110;    // senha padrão (1º dígito é 1)
           passcode[1] <= 4'b1101;    // senha padrão 2 (2º dígito é 2)
           passcode[2] <= 4'b1011;    // senha padrão 3 (3º dígito é 3)
           qtd_erros <= 2'b00;        // zera erros
           qtd_acertos <= 2'b00;      // zera acertos
           segundos <= 4'd0;          // zera contador de segundos
           leds_segundos <= 10'd0;    // apaga LEDs de segundos
           ms_index <= 2'd0;          // índice de mudança de senha
 			  div_count <= 26'd0;
			  one_hz <= 1'b0;
		end
		else if (state == CONT) begin             // estado de bloqueio: contar até 10 segundos
			if (div_count == 50_000_000 - 1) begin
				div_count <= 0;
				one_hz <= 1'b1;
			end
			else begin
				div_count <= div_count + 1;
				one_hz <= 0;
			end
			if (one_hz) begin
				segundos <= segundos + 1;
				leds_segundos <= (10'b1 << (segundos + 1)) - 1; // acende LEDs progressivamente
			end
        end else begin
			div_count <= 26'd0;  // reseta divisor se não estiver em CONT (pode ajustar conforme quiser)
			one_hz <= 1'b0;
			segundos <= 4'd0;
			leds_segundos <= 10'd0;
		end
		
        // início do modo de mudança de senha
        if (ms) begin          
			if (state == MS0 || state == MS1 || state == MS2) begin 
				if (btn == 4'b1111 && state_wait_release != state) begin	  // só grava quando botão for solto e houver transição armazenada
                    passcode[ms_index] <= last_btn_pressed;    // grava segundo botão
                    ms_index <= ms_index + 1;     // passa para próximo índice
                end
            end else begin
                ms_index <= 2'd0;        		  // zera índice caso não esteja no MS0, MS1 ou MS2 
			end
		end
      // novo erro 
      // apenas um incremento por ciclo
		if (next == ERRO && state != ERRO) begin
            qtd_erros <= (qtd_erros < 3) ? qtd_erros + 1 : qtd_erros;
      end  
		if ((state == S0 && btn == passcode[0]) || (state == S1 && btn == passcode[1]) || (state == S2 && btn == passcode[2])) begin
         qtd_acertos <= qtd_acertos + 1;	
		end
				
      // cofre destrancado
		if (state == S3) begin
            qtd_erros <= 2'b00; 	      // zerar erros 
			   qtd_acertos <= 2'b00;      // zera acertos
            segundos <= 4'd0;          // zera contador de segundos
            leds_segundos <= 10'd0;    // apaga LEDs de segundos
            ms_index <= 2'd0;          // índice de mudança de senha
      end
    end

    // lógica combinacional -> atualiza estado
    always_comb begin
        next = state; // valor padrão do próximo estado
        case (state) 
            S0: begin // libera a transição armazenada quando o botão é solto
						 if (btn == 4'b1111) begin
							  next = (state_wait_release != S0) ? state_wait_release : S0; // libera transição armazenada
						 end else begin
							  next = (btn != passcode[0]) ? ERRO : S1;                     // botão errado → ERRO, botão certo → S1
						 end
					 end
					
            S1:  begin
						 if (btn == 4'b1111) begin
							  next = (state_wait_release != S1) ? state_wait_release : S1; // libera transição armazenada
						 end else begin
							  next = (btn != passcode[1]) ? ERRO : S2;                     // botão errado → ERRO, botão certo → S1
						 end
					 end

            S2:  begin
						 if (btn == 4'b1111) begin
							  next = (state_wait_release != S2) ? state_wait_release : S2; // libera transição armazenada
						 end else begin
							  next = (btn != passcode[2]) ? ERRO : S3;                     // botão errado → ERRO, botão certo → S1
						 end
					 end   
				
            S3:    next = (ms) ? MS0 : S3;                   // se ms ativo, vai pra estado de mudança de senha / se não, fica em S3 (unlocked)
            MS0:   begin
							 if (btn == 4'b1111) begin
								  if (state_wait_release != MS0)
										next = state_wait_release; // libera transição armazenada
								  else
										next = MS0;
							 end 
						 end
            MS1:   begin
							 if (btn == 4'b1111) begin
								  if (state_wait_release != MS1)
										next = state_wait_release;
								  else
										next = MS1;
							 end
						 end
            MS2:   begin
							 if (btn == 4'b1111) begin
								  if (state_wait_release != MS2)
										next = state_wait_release;
								  else
										next = MS2;
							 end
						 end
            ERRO: begin
						 if (btn == 4'b1111) begin
							  if (qtd_erros >= 3)
									next = CONT;
							  else
									next = state_before_error;
						 end
						 else begin
							  next = ERRO; // segura em ERRO enquanto botão estiver pressionado
						 end
					end
            CONT:  next = (segundos >= 4'd10) ? S0 : CONT;   // espera 10 segundos
            default: next = S0;
        endcase
    end

    // outputs
    always_comb begin
        unlocked = (state == S3); // destrava quando chega no estado S3
        
        // LEDs de erros (acende progressivamente conforme número de erros)
        leds_erros[0] = (qtd_erros >= 2'd1);
        leds_erros[1] = (qtd_erros >= 2'd2);
        leds_erros[2] = (qtd_erros >= 2'd3);

        // LEDs de acertos (acende progressivamente conforme número de acertos)
        leds_acertos[0] = (qtd_acertos >= 2'd1);
        leds_acertos[1] = (qtd_acertos >= 2'd2);
        leds_acertos[2] = (qtd_acertos >= 2'd3);
    end
endmodule
