module safecrack_fsm (
    input  logic       clk,            // clock
    input  logic       rst,            // reset
    input  logic       ms,             // mudança de senha 
    input  logic [3:0] btn,            // buttons inputs (BTN[3:0])
    output logic       unlocked,       // output: 1 quando o cofre é destravado
    output logic [2:0] leds_erros,     // output: 1 quando tiver errado
    output logic [2:0] leds_acertos,   // output: 1 quando tiver errado
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

    // --- ADIÇÃO ---
    // registrador para guardar o estado antes do erro, para poder retornar a ele.
    state_t state_before_error;    // guarda o estado antes do erro para voltar a ele

    logic [3:0] passcode[2:0];     // armazena a senha (3 dígitos)
    logic [1:0] qtd_erros;         // armazena a quantidade de erros (zerada no reset)
    logic [1:0] qtd_acertos;       // armazena a quantidade de acertos (zerada no reset)
    logic [3:0] segundos;          // contador de segundos no bloqueio (0–10)
    logic [1:0] ms_index;          // índice para mudança de senha

    // --- LÓGICA SEQUENCIAL --- 
    // atualização de estado e registradores ---
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset geral
            state <= S0;
            passcode[0] <= 4'b1110;    // senha padrão 1
            passcode[1] <= 4'b1101;    // senha padrão 2
            passcode[2] <= 4'b1011;    // senha padrão 3
            qtd_erros <= 2'b00;        // zera erros
            qtd_acertos <= 2'b00;      // zera acertos
            segundos <= 4'd0;          // zera contador de segundos
            leds_segundos <= 10'b0;    // apaga LEDs de segundos
            state_before_error <= S0;  // estado inicial antes de erro
            ms_index <= 2'd0;          // índice de mudança de senha
        end
        else if (state == CONT) begin
            // estado de bloqueio: contar até 10 segundos
            if (segundos < 4'd10) begin
                segundos <= segundos + 1;            // soma 1 segundo
                leds_segundos[segundos] <= 1'b1;     // acende LED correspondente
            end else begin
                // ao fim dos 10s: reset de contadores e volta ao estado inicial
                segundos <= 4'd0;                    // zera segundos
                leds_segundos <= 10'b0;               // apaga LEDs de segundos
                qtd_erros <= 2'b00;                   // zera erros
                qtd_acertos <= 2'b00;                 // zera acertos
                state <= S0;                          // volta para estado inicial
            end
        end
        else if (ms) begin
            // início do modo de mudança de senha
            state <= MS0;              // vai para captura do 1º botão
            ms_index <= 2'd0;          // zera índice
            qtd_acertos <= 2'b00;      // zera acertos ao mudar senha
        end
        else begin
            // --- MODO MUDANÇA DE SENHA: --- 
            // captura apenas quando houver um botão válido
            // (4'b1111 representa "nenhum botão pressionado")
            if (state == MS0) begin
                if (btn != 4'b1111) begin
                    passcode[0] <= btn;   // grava primeiro botão
                    ms_index <= 2'd1;     // passa para próximo índice
                end
            end else if (state == MS1) begin
                if (btn != 4'b1111) begin
                    passcode[1] <= btn;   // grava segundo botão
                    ms_index <= 2'd2;     // passa para próximo índice
                end
            end else if (state == MS2) begin
                if (btn != 4'b1111) begin
                    passcode[2] <= btn;   // grava terceiro botão
                    ms_index <= 2'd0;     // reinicia índice
                end
            end

            // novo erro 
            if (next == ERRO && state != ERRO) begin
                state_before_error <= state; // salva estado atual para poder voltar depois
                qtd_erros <= qtd_erros + 1;  // incrementa erros
                qtd_acertos <= 2'b00;        // zera acertos após erro
            end

            // acertos 
            if ((state == S0 && next == S1) ||
                (state == S1 && next == S2) ||
                (state == S2 && next == S3)) begin
                qtd_acertos <= qtd_acertos + 1;
            end

            // zerar erros (cofre destravado)
            if (state == S3) begin
                qtd_erros <= 2'b00;
            end

            // atualizar estado
            state <= next;
        end
    end

    // --- LÓGICA COMBINACIONAL ---
    // definição do próximo estado 
    always_comb begin
        next = state; // valor padrão do próximo estado
        case (state) 
            S0:    next = (btn == passcode[0]) ? S1 : ERRO;  // verifica 1º dígito
            S1:    next = (btn == passcode[1]) ? S2 : ERRO;  // verifica 2º dígito
            S2:    next = (btn == passcode[2]) ? S3 : ERRO;  // verifica 3º dígito
            S3:    next = (ms) ? MS0 : S3;                   // se ms ativo, muda senha
            MS0:   next = (btn != 4'b1111) ? MS1 : MS0;      // espera botão válido
            MS1:   next = (btn != 4'b1111) ? MS2 : MS1;      // espera botão válido
            MS2:   next = (btn != 4'b1111) ? S0  : MS2;      // espera botão válido
            ERRO: begin
                if (qtd_erros >= 3)       next = CONT;              // se 3 erros → bloqueia
                else if (btn == 4'b1111)  next = state_before_error; // volta ao estado antes do erro
                else                      next = ERRO;              // mantém erro enquanto botão pressionado
            end
            CONT:  next = (segundos >= 4'd10) ? S0 : CONT;  // espera 10 segundos
            default: next = S0;
        endcase
    end

    // --- LÓGICA DE SAÍDA ---
    // definição de sinais externos ---
    always_comb begin
        unlocked = (state == S3); // destrava quando chega no estado S3

        // LEDs de erros (acende progressivamente conforme número de erros)
        leds_erros[0] = (qtd_erros >= 2'b01);
        leds_erros[1] = (qtd_erros >= 2'b10);
        leds_erros[2] = (qtd_erros >= 2'b11);

        // LEDs de acertos (acende progressivamente conforme número de acertos)
        leds_acertos[0] = (qtd_acertos >= 2'b01);
        leds_acertos[1] = (qtd_acertos >= 2'b10);
        leds_acertos[2] = (qtd_acertos >= 2'b11);
    end

endmodule
