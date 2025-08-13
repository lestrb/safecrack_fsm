module safecrackpro_beta_fsm (
    input  logic       clk,            // clock
    input  logic       rst,            // reset
    input  logic       ms,             // mudança de senha 
    input  logic [3:0] btn,            // buttons inputs (BTN[3:0])
    output logic       unlocked        // output: 1 quando o cofre é destravado
    output logic [2:0] leds_erros      // output: 1 quando tiver errado
    output logic [2:0] leds_acertos    // output: 1 quando tiver errado
    output logic [9:0] leds_segundos;  // output: 1 enquanto contar os segundos
);

    // one-hot encoding | criação de estados
    typedef enum logic [9:0] { 
        S0 = 9'b0_0000_0001,       // estado inicial
        S1 = 9'b0_0000_0010,       // BTN = 1 right
        S2 = 9'b0_0000_0100,       // BTN = 2 right
        S3 = 9'b0_0000_1000,       // BTN = 3 right → unlock
        MS0 = 9'b0_0001_0000,      // ao clicar em qualquer BTN → próximo estado
        MS1 = 9'b0_0010_0000,      // ao clicar em qualquer BTN → próximo estado
        MS2 = 9'b0_0100_0000,      // ao clicar em qualquer BTN → S0
        ERRO = 9'b0_1000_0000,     // errando tentativa de senha
        CONT = 9'b1_0000_0000      // sistema travado → inicia-se o contador de 10s
    } state_t;

    state_t state, next;           // state pode assumir valores do typedef

    // --- ADIÇÃO ---
    // Registrador para guardar o estado antes do erro, para poder retornar a ele.
    state_t state_before_error;

    logic [3:0] passcode[2:0];         // armazena a senha
    logic [1:0] qtd_erros;             // armazena a quantidade de erros (zerada no reset)
    logic [1:0] qtd_acertos;           // armazena a quantidade de acertos (zerada no reset)
    logic [1:0] tentativa_incorreta;   // armazena quantidade de tentativas incorretas (zerada no reset)
    logic [3:0] segundos;              // conta de 0 a 10, usa 4 bits (zerada pós contagem)
    
    // state transition (depende do clock)
    always_ff @(posedge clk) begin
        if (state == CONT) begin // trata o contador de tempo
            if (segundos < 4'd10) begin
                segundos <= segundos + 1;        // soma mais 1 segundo
                leds_segundos[segundos] <= 1'b1; // acende LED correspondente (bit referente ao idx vai pra 1)
            end
            else begin
                segundos <= 2'd0;            // volta a 0 quando for >= 10
                state <= S0;                 // reseta estado pra S0 depois de travar por 10s
            end
        end
        else if (rst) begin // reseta
            state <= S0;
            passcode[0] <= 4'b1110;              // senha volta a ser 1 2 3 com o reset
            passcode[1] <= 4'b1101;
            passcode[2] <= 4'b1011;
            qtd_acertos <= 2'b00;                // zera contador de acertos
            qtd_erros <= 2'b00;                  // zera contador de erros
            segundos <= 4'd0;                    // zera contador de segundos
            leds_segundos <= 10'b00_0000_0000;   // desliga leds dos segundos (tudo 0)
            state_before_error <= S0; // Reseta o estado de erro também
        end
        else if (ms) begin
            state <= MS0;
            passcode[0] <= btn; // VER COMO ARMAZENAR ESSES BOTÕES APERTADOS
            passcode[1] <= btn;
            passcode[2] <= btn;
            qtd_erros <= 2'b00; 
            qtd_acertos <= 2'b00;
        end
        else begin
            // Se o próximo estado for ERRO e o estado atual não for,
            // significa que um novo erro acabou de acontecer.
            if (next == ERRO && state != ERRO) begin
                state_before_error <= state; // Salva o estado atual para poder retornar
                qtd_erros <= qtd_erros + 1;  // Incrementa o contador de erros
            end

            // Se o cofre for destravado ou o tempo de bloqueio acabar, zera os erros
            if (state == S3 || (state == CONT && segundos >= 4'd10)) begin
                qtd_erros <= 2'b00;
            end
            state <= next; // muda estado com o clock
        end
    end

    // transition logic -> combinacional (atualiza estado)
    always_comb begin
        next = S0; // default
        case (state) 
            S0:    next = (btn == passcode[0]) ? S1 : ERRO;  // se o botão tiver pressionado for o que eu defini pro passcode[0], vai pra estado S1 / se não, vai pra ERRO
            S1:    next = (btn == passcode[1]) ? S2 : ERRO;
            S2:    next = (btn == passcode[2]) ? S3 : ERRO;
            S3:    next = (ms) ? MS0 : S3;                   // se ms for 1 (switch pra cima), muda de estado (somente quando tiver em S3)
            MS0:   next = (btn) ? MS1 : MS0;                 // se qualquer botão for 0 (pressionado), vai pro MS1
            MS1:   next = (btn) ? MS2 : MS1;                 // se qualquer botão for 0 (pressionado), vai pro MS2
            MS2:   next = (btn) ? S0 : MS2;                  // se qualquer botão for 0 (pressionado), vai pro S0
            ERRO: begin
                // Se cometeu o 3º erro, vai para o estado de CONTagem
                if (qtd_erros >= 3) begin
                    next = CONT;
                end 
                // Se cometeu menos de 3 erros...
                else begin
                    // ...espera o botão ser solto para voltar ao estado anterior
                    if (btn == 4'b1111) begin
                        next = state_before_error;
                    end 
                    // Enquanto o botão estiver pressionado, permanece no estado de ERRO
                    else begin
                        next = ERRO; 
                    end
                end
            end
            CONT:  next = (segundos >= 4'd10) ? S0 : CONT;   // se passaram 10 segundos, vai pra S0 / se não, fica em CONT
            default: next = S0;                              // caso não seja nenhum dos estados previstos
        endcase
    end

    // output logic -> combinacional (atualisa saída)
    always_comb begin
        unlocked = (state == S3);                  // se state é S3, unlocked = 1 / se não, unlocked = 0
        leds_erros[0] = (qtd_erros >= 2'b01);      // se a qtd_erros for >= 1, acende 1ª led vermelha
        leds_erros[1] = (qtd_erros >= 2'b10);      // se a qtd_erros for >= 2, acende 2ª led vermelha
        leds_erros[2] = (qtd_erros >= 2'b11);      // se a qtd_erros for >= 3, acende 3ª led vermelha
        leds_acertos[0] = (qtd_acertos >= 2'b01);  // funciona igual aos erros
        leds_acertos[1] = (qtd_acertos >= 2'b10); 
        leds_acertos[2] = (qtd_acertos >= 2'b11); 
    end
endmodule
