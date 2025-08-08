# 🔐 SafeCrackPro Beta FSM

Projeto de uma **máquina de estados finita (FSM)** em **SystemVerilog** para simular um cofre eletrônico.  
O sistema valida uma senha pré-definida, conta erros e acertos, permite alteração de senha e aplica um tempo de bloqueio após tentativas incorretas.

---

## 📋 Funcionalidades

- **Validação de senha** com três etapas (passcode de 3 dígitos).
- **Contagem de acertos e erros** com LEDs indicadores.
- **Mudança de senha** via modo de configuração.
- **Bloqueio temporário** de 10 segundos após 3 tentativas incorretas.
- **Indicação visual**:
  - LEDs vermelhos para erros (`leds_erros`)
  - LEDs verdes para acertos (`leds_acertos`)
  - LED verde para quando desbloquear (`unlocked`)
  - LEDs vermelhos sequenciais para contagem de segundos de bloqueio (`leds_segundos`).

---

## 🛠 Estrutura do Sistema

O projeto é implementado como uma FSM **one-hot** com os seguintes estados:

| Estado  | Função |
|---------|--------|
| `S0`    | Estado inicial, aguardando o primeiro dígito da senha |
| `S1`    | Primeiro dígito correto, aguardando o segundo |
| `S2`    | Segundo dígito correto, aguardando o terceiro |
| `S3`    | Senha correta → cofre desbloqueado |
| `MS0`   | Alteração de senha: captura do primeiro dígito |
| `MS1`   | Alteração de senha: captura do segundo dígito |
| `MS2`   | Alteração de senha: captura do terceiro dígito |
| `ERRO`  | Entrada incorreta de senha |
| `CONT`  | Cofre bloqueado por 10 segundos |

---

## ⚙️ Entradas e Saídas

### Entradas
- `clk` → clock do sistema
- `rst` → reset geral
- `ms` → habilita modo de alteração de senha
- `btn[3:0]` → botões para entrada de dígito da senha

### Saídas
- `unlocked` → indica se o cofre está destravado
- `leds_erros[2:0]` → indica quantidade de erros
- `leds_acertos[2:0]` → indica quantidade de acertos
- `leds_segundos[9:0]` → barra de contagem visual de segundos durante bloqueio

---

## 🔄 Lógica de Bloqueio por Tempo

Quando o estado `CONT` é ativado:
1. O contador `segundos` incrementa a cada ciclo de clock.
2. O LED correspondente ao segundo atual é aceso.
3. Ao atingir **10 segundos**, o contador é zerado e o estado volta para `S0`.

---

## 🚀 Como Usar

1. Compile o arquivo `safecrack_fsm.sv` em seu ambiente/ferramenta de simulação FPGA ou SystemVerilog.
2. Configure as entradas (`clk`, `rst`, `ms`, `btn`) no simulador.
3. Observe as saídas (`unlocked`, `leds_erros`, `leds_acertos`, `leds_segundos`) para verificar o funcionamento.

---

## 📌 Observações

- A senha padrão no reset é **1 2 3** (`1110`, `1101`, `1011`).
- Para resetar, ative o switch relacionado ao `rst`.
- Para alterar a senha, ative o switch relacionado ao `ms` e insira os 3 novos dígitos.
- Após 3 erros, o sistema entra no estado `CONT` e bloqueia por 10 segundos.
- LEDs de segundos acendem de forma cumulativa (efeito barra de progresso).
