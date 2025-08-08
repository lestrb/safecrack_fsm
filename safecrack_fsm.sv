module safecrackpro_beta_fsm (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] btn,        // buttons inputs (BTN[3:0])
    output logic       unlocked    // output: 1 when the safe is unlocked
);

    // one-hot encoding  ---- criar estados diferentes para a troca de senhas aqui
    typedef enum logic [3:0] { // typedef -> estados da maquina
        S0 = 4'b0001,  // initial state
        S1 = 4'b0010,  // BTN = 1 right
        S2 = 4'b0100,  // BTN = 2 right
        S3 = 4'b1000  // BTN = 4 right → unlock
// ex: S4 = 5'b10000
// muda os S0, S1, S2 e S3 pra S3 = 5'b01000,
// o ultimo sem virgula
    } state_t;

    state_t state, next;

    logic [3:0] passcode[2:0]; // variavel que armazena o codigo (registrador) -> vai precisar de uma logic pra armazenar o tempo e a qtd de erros

    // state transition -> depende do clock
    always_ff @(posedge clk) begin
        if (rst) begin // reseta
            state <= S0;
            passcode[0] <= 4'b0111;
            passcode[1] <= 4'b1101;
            passcode[2] <= 4'b1101;
        end
        else begin
            state <= next; // muda estado com o clock
        end
    end

    // transition logic -> combinacional (atualiza estado)
    always_comb begin
        next = S0; // default
        case (state) // state pode assumir valores do typedef
            S0:    next = (btn == passcode[0]) ? S1 : S0; // caso o estado seja S0, next recebe S1 se o botão tiver pressionado o que eu defini pro passcode[0] / se não, continua S0
            S1:    next = (btn == passcode[1]) ? S2 : S1;
            S2:    next = (btn == passcode[2]) ? S3 : S2;
            S3:    next = S3;
            default: next = S0; // caso não seja nenhum dos estados previstos
        endcase
    end

    // output logic -> combinacional (atualisa saída)
    always_comb begin
        unlocked = (state == S3); // pergunta se estado é igual a S3 (se sim, unlocked = 1 / se não, unlocked = 0)
    end

endmodule
