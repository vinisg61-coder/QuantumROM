# A52s Camera CSL — mitigação sem wipe

Módulo **Magisk/KernelSU v1.2** para investigar a falha da câmera 1x sem apagar dados. A instalação usa overlay systemless, não remonta nem escreve o `/vendor` real, não toca em `/data` e não executa wipe.

## Escopo técnico

O pacote altera somente o `raise(6)` confirmado no backtrace: `CSLAcquireDeviceHW+1764` dentro de `/vendor/lib64/hw/camera.qcom.so`, BuildId `9b26d985843faf46e36d82967f1c1526`, offset `0xc88b4c` (`49 a1 01 94` → NOP `1f 20 03 d5`). O módulo verifica o SHA-256 original e o SHA-256 pós-patch; em binário desconhecido, recusa a alteração.

A alteração é uma **mitigação de crash-loop**, não uma correção comprovada do sensor. Os artefatos mostram também NACK I²C em `0x34`, `rc=-22`, ausência de dados GPIO, sequência de reguladores inconsistente e erros de EEPROM/CRC. Esses sinais ainda precisam de correção/validação no DT/DTBO, vendor e hardware.

## Instalação sem wipe

No Magisk ou KernelSU, escolha instalar o arquivo `A52s_Camera_CSL_Overlay_v1.2_Systemless.zip` como módulo e reinicie. Não use opções de wipe. Durante a instalação, o script copia a biblioteca original do aparelho para o diretório privado do módulo, aplica o NOP, confere o SHA-256 e monta o resultado de forma systemless. O log fica em `/data/adb/modules/a52s_camera_no_abort/patch.log`.

## Remoção e recuperação

Desative/remova o módulo pelo Magisk ou KernelSU e reinicie. Como o patch fica somente no overlay, remover o módulo desfaz a alteração no próximo boot; o `uninstall.sh` não remonta nem sobrescreve o vendor.

## Native CAX v1

O pacote Native CAX v1 não está presente nos artefatos fornecidos e não há marca inequívoca de sua instalação nos logs. Se esta captura foi feita depois de instalá-lo, o provider continuou abortando e a câmera 0 continuou indisponível; portanto não há progresso funcional demonstrado. Progresso real exigirá sensor ID lido, ausência de NACK e frames 1x entregues.

## Arquivos

| Arquivo | Função |
|---|---|
| `A52s_Camera_CSL_Overlay_v1.2_Systemless.zip` | Pacote instalável por Magisk/KernelSU |
| `customize.sh` | Copia, patcha e valida o overlay durante a instalação |
| `service.sh` | Verifica o overlay no boot sem escrever |
| `uninstall.sh` | Remove o estado do módulo; rollback por remoção do overlay |
| `sepolicy.rule` | Nenhuma permissão extra; mantido por compatibilidade |
