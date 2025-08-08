module safecrackpro_beta_fsm (
    input  logic       clk,        // clock
    input  logic       rst,        // reset
    input  logic       ms,         // mudança de senha
    input  logic [3:0] btn,        // buttons inputs (BTN[3:0])
    output logic       unlocked    // output: 1 when the safe is unlocked
    output logic       first       // output: 1 quando tiver errado uma vez
    output logic       second      // output: 1 quando tiver errado duas vezes
    output logic       third       // output: 1 quando tiver errado três vezes
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
    // criar essas pra armazenar tempo 
    
    // state transition -> depende do clock
    always_ff @(posedge clk) begin
        if (rst) begin // reseta
            state <= S0;
            passcode[0] <= 4'b0111;
            passcode[1] <= 4'b1101;
            passcode[2] <= 4'b1101;
            qtd_erros <= 2'b00;          // zera contador de erros
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
            MS1:    next = (btn) ? MS2 : MS1;
            MS2:    next = (btn) ? S0 : MS2;
            ERRO:  // FAZER TRATATIVA DE QUANDO FOR ERRO
            default: next = S0; // caso não seja nenhum dos estados previstos
        endcase
    end

    // output logic -> combinacional (atualisa saída)
    always_comb begin
        unlocked = (state == S3); // pergunta se estado é igual a S3 (se sim, unlocked = 1 / se não, unlocked = 0)
        first = (qtd_erros == 2'b01);     // se a qtd_erros for 1, first == 1, vamos colocar pra acender led vermelha
        second = (qtd_erros == 2'b10);
        third = (qtd_erros == 2'b11);
    end

endmodule
