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

    logic [3:0] passcode[2:0];     // armazena a senha (3 dígitos)
    logic [1:0] qtd_erros;         // armazena a quantidade de erros (zerada no reset)
    logic [1:0] qtd_acertos;       // armazena a quantidade de acertos (zerada no reset)
    logic [3:0] segundos;          // contador de segundos no bloqueio (0–10)
    logic [1:0] ms_index;          // índice para mudança de senha
	 logic [25:0] div_count; 		  // 26 bits conseguem contar até 67 milhões
	 logic        one_hz;           // pulso de 1 Hz

    // transição de estado e registradores (de acordo com o clock)
    always_ff @(posedge clk) begin     
        if (rst) begin                 // Reset geral
            state <= S0;
            passcode[0] <= 4'b1110;    // senha padrão (1º dígito é 1)
            passcode[1] <= 4'b1101;    // senha padrão 2 (2º dígito é 2)
            passcode[2] <= 4'b1011;    // senha padrão 3 (3º dígito é 3)
            qtd_erros <= 2'b00;        // zera erros
            qtd_acertos <= 2'b00;      // zera acertos
            segundos <= 4'd0;          // zera contador de segundos
            leds_segundos <= 10'd0;    // apaga LEDs de segundos
            state_before_error <= S0;  // estado inicial antes de erro
            ms_index <= 2'd0;          // índice de mudança de senha
				div_count <= 26'd0;
				one_hz <= 1'b0;
				segundos <= 0;
				leds_segundos <= 0;
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
				segundos <= 0;
				leds_segundos <= 0;
		  end
		  
        // início do modo de mudança de senha
        if (ms) begin          
				if (state == MS0) begin // captura apenas quando houver um botão válido (4'b1111 representa "nenhum botão pressionado")
                // Zera tudo que tem que zerar no MS0 (não zera erros porque já foi zerado no S3)
                qtd_acertos <= 2'b00;      // zera acertos
                segundos <= 4'd0;          // zera contador de segundos
                leds_segundos <= 10'd0;    // apaga LEDs de segundos
                state_before_error <= S0;  // estado inicial antes de erro
                ms_index <= 2'd0;          // índice de mudança de senha
                
                if (btn != 4'b1111) begin
                    passcode[ms_index] <= btn;    // grava primeiro botão
                    ms_index <= ms_index + 1;     // passa para próximo índice
                end
            end else if (state == MS1 || state == MS2) begin
                if (btn != 4'b1111) begin
                    passcode[ms_index] <= btn;    // grava segundo botão
                    ms_index <= ms_index + 1;     // passa para próximo índice
                end
            end else begin
                ms_index <= 2'd0;        	 // zera índice caso não esteja no MS0, MS1 ou MS2 
				end
		  end
        // novo erro 
        else if (next == ERRO && state != ERRO) begin
            state_before_error <= state;            							 // salva estado atual para poder voltar depois
            qtd_erros <= (qtd_erros < 3) ? qtd_erros + 1 : qtd_erros;    // incrementa erros
        end    
		  // Zera erros quando volta ao estado inicial sem estar bloqueado
		  else if (state == ERRO && next == state_before_error && state_before_error == S0) begin
				qtd_erros <= 2'b00;
		  end
        // novo acerto 
        else if ((state == S0 && next == S1) || (state == S1 && next == S2) || (state == S2 && next == S3)) begin 
            qtd_acertos <= qtd_acertos + 1;
        end
        // cofre destrancado
        else if (state == S3) begin
            qtd_erros <= 2'b00; // zerar erros 
        end
        // atualiza estado
        state <= next;
    end

    // lógica combinacional -> atualiza estado
    always_comb begin
        next = state; // valor padrão do próximo estado
        case (state) 
            S0:	 begin  
							 if (btn == 4'b1111)           next = S0; 	 // se não tem botão pressionado, fica em S0
							 else if (btn == passcode[0])  next = S1;     // se acertar o botão, vai pro próximo estado
							 else								    next = ERRO;   // se não acertar botão, vai pra ERRO
						 end
            S1:    begin  
							 if (btn == 4'b1111)           next = S1; 	 // se não tem botão pressionado, fica em S1
							 else if (btn == passcode[1])  next = S2;     // se acertar o botão, vai pro próximo estado
							 else							       next = ERRO;   // se não acertar botão, vai pra ERRO
						 end
            S2:    begin  
							 if (btn == 4'b1111)           next = S2; 	 // se não tem botão pressionado, fica em S2
							 else if (btn == passcode[2])  next = S3;     // se acertar o botão, vai pro próximo estado
							 else							       next = ERRO;   // se não acertar botão, vai pra ERRO
						 end
            S3:    next = (ms) ? MS0 : S3;                   // se ms ativo, vai pra estado de mudança de senha / se não, fica em S3 (unlocked)
            MS0:   next = (btn != 4'b1111) ? MS1 : MS0;      // espera botão válido
            MS1:   next = (btn != 4'b1111) ? MS2 : MS1;      // espera botão válido
            MS2:   next = (btn != 4'b1111) ? S0  : MS2;      // espera botão válido
            ERRO:  begin  
							 if (btn == 4'b1111)       next = ERRO; // se 3 erros → bloqueia
							 else if (qtd_erros >= 3)  next = CONT; // volta ao estado antes do erro
							 else								next = state_before_error; // mantém erro enquanto botão pressionado
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
