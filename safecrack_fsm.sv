module safecrackpro_beta_fsm (
    input  logic       clk,        // clock
    input  logic       rst,        // reset
    input  logic       ms,         // mudança de senha
    input  logic       trava, 
    input  logic [3:0] btn,        // buttons inputs (BTN[3:0])
    output logic       unlocked    // output: 1 when the safe is unlocked
    output logic [2:0] leds_erros  // output: 1 quando tiver errado uma vez
    output logic [9:0] leds_segundos;      
);

    // one-hot encoding  ---- criar estados diferentes para a troca de senhas aqui
    typedef enum logic [3:0] { // typedef -> estados da maquina
        S0 = 9'b0_0000_0001,  // initial state
        S1 = 9'b0_0000_0010,  // BTN = 1 right
        S2 = 9'b0_0000_0100,  // BTN = 2 right
        S3 = 9'b0_0000_1000,  // BTN = 3 right → unlock
        MS0 = 9'b0_0000_0000, // CHECAR QUAIS SERIAM OS 1 EM CADA NOVO ESTADO DAQUI PRA BAIXO
        MS1 = 9'b0_0000_0000,
        MS2 = 9'b0_0000_0000,
        ERRO = 9'b0_0000_0000,
        CONT = 9'b0_0000_0000
// ex: S4 = 5'b10000
// muda os S0, S1, S2 e S3 pra S3 = 5'b01000,
// o ultimo sem virgula
    } state_t;

    state_t state, next;

    logic [3:0] passcode[2:0]; // armazena o codigo (registrador) -> vai precisar de uma logic pra armazenar o tempo e a qtd de erros
    logic [1:0] qtd_erros;     // armazena a quantidade de erros (será zerada no reset)
    logic tentativa_incorreta;
    logic [1:0] segundos; // como vamos usar decimal, precisa somente de 2 bits
    
    // state transition -> depende do clock
    always_ff @(posedge clk) begin
        if (trava) begin // trata o contador de tempo
            if (segundos < 4'd10) begin
                segundos <= segundos + 1;    // soma mais 1
                leds_segundos[segundos] <= 1'b1; // acende LED correspondente
            end
            else begin
                segundos <= 2'd0;            // volta a 0 quando passar de 10
                state <= S0;                 // reseta estado pra S0 depois de travar por 10s
            end
        end
        else if (rst) begin // reseta
            state <= S0;
            passcode[0] <= 4'b0111;
            passcode[1] <= 4'b1101;
            passcode[2] <= 4'b1101;
            qtd_erros <= 2'b00;          // zera contador de erros
            segundos <= 2'd0;            // zera contador de segundos
            leds_segundos <= 10'b00_0000_0000; // desliga leds dos segundos
        end
        else if (ms) begin
            state <= MS0;
            passcode[0] <= btn; // PODE SER ASSIM???
            passcode[1] <= btn;
            passcode[2] <= btn;
            qtd_erros <= 2'b00; 
        end
        else if (tentativa_incorreta) begin ////// APLICAR MUDANÇA DE ESTADO PRA CHECAR QTD E DECIDIR SE ITERA OU SE VAI PRO CONTADOR DE TEMPO
            qtd_erros <= qtd_erros + 1
        end
        else begin
            state <= next; // muda estado com o clock
        end
    end

    // transition logic -> combinacional (atualiza estado)
    always_comb begin
        next = S0; // default
        case (state) // state pode assumir valores do typedef
            S0:    next = (btn == passcode[0]) ? S1 : ERRO; // caso o estado seja S0, next recebe S1 se o botão tiver pressionado o que eu defini pro passcode[0] / se não, continua S0
            S1:    next = (btn == passcode[1]) ? S2 : ERRO;
            S2:    next = (btn == passcode[2]) ? S3 : ERRO;
            S3:    next = (ms) ? MS0 : S3; // se ms for 1 (switch pra cima), muda de estado ---- CHECAR SE ESSE JEITO DE COMPARAR TÁ CERTO
            MS0:    next = (btn) ? MS1 : MS0; // se qualquer botão for 1 (pressionado), muda de estado  ---- CHECAR SE BOTÃO PRESSIONADO É 0 OU 1
            MS1:    next = (btn) ? MS2 : MS1; // falta armazenar o botão pressionado ---- VER COMO FAZER
            MS2:    next = (btn) ? S0 : MS2;
            ERRO:  // FAZER TRATATIVA DE QUANDO FOR ERRO
                CONT:  // FAZER TRATATIVA DE QUANDO CHEGAREM 3 ERROS E FOR PRO ESTADO DE CONT (contar os 10seg)
            default: next = S0; // caso não seja nenhum dos estados previstos
        endcase
    end

    // output logic -> combinacional (atualisa saída)
    always_comb begin
        unlocked = (state == S3); // pergunta se estado é igual a S3 (se sim, unlocked = 1 / se não, unlocked = 0)
        leds_erros[0] = (qtd_erros == 2'b01);     // se a qtd_erros for 1, first == 1, vamos colocar pra acender led vermelha
        leds_erros[1] = (qtd_erros == 2'b10);
        leds_erros[2] = (qtd_erros == 2'b11);
    end

endmodule
