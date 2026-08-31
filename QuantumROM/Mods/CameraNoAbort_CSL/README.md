# A52s Camera CSL — mitigação sem wipe

Módulo **Magisk/KernelSU** para investigar a falha da câmera 1x sem apagar dados. A instalação não toca em `/data` nem executa wipe.

## Escopo técnico

O pacote altera somente o `raise(6)` confirmado no backtrace: `CSLAcquireDeviceHW+1764` dentro de `/vendor/lib64/hw/camera.qcom.so`, BuildId `9b26d985843faf46e36d82967f1c1526`, offset `0xc88b4c` (`49 a1 01 94` → NOP `1f 20 03 d5`). O módulo verifica o SHA-256 original e o SHA-256 pós-patch; em binário desconhecido, recusa a alteração.

A alteração é uma **mitigação de crash-loop**, não uma correção comprovada do sensor. Os artefatos mostram também NACK I²C em `0x34`, `rc=-22`, ausência de dados GPIO, sequência de reguladores inconsistente e erros de EEPROM/CRC. Esses sinais ainda precisam de correção/validação no DT/DTBO, vendor e hardware.

## Instalação sem wipe

No Magisk ou KernelSU, escolha instalar o arquivo `a52s-camera-no-abort-csl.kernelsu.zip` como módulo e reinicie. Não use opções de wipe. O módulo salva backup, verifica a escrita e solicita o restart do camera provider. O log fica em `/data/adb/modules/a52s_camera_no_abort/patch.log`.

## Remoção e recuperação

Desative/remova o módulo pelo Magisk ou KernelSU e reinicie. O `uninstall.sh` restaura a cópia somente quando o binário atual ainda corresponde ao hash do patch; se o estado for desconhecido, ele não sobrescreve o vendor.

## Native CAX v1

O pacote Native CAX v1 não está presente nos artefatos fornecidos e não há marca inequívoca de sua instalação nos logs. Se esta captura foi feita depois de instalá-lo, o provider continuou abortando e a câmera 0 continuou indisponível; portanto não há progresso funcional demonstrado. Progresso real exigirá sensor ID lido, ausência de NACK e frames 1x entregues.

## Arquivos

| Arquivo | Função |
|---|---|
| `a52s-camera-no-abort-csl.kernelsu.zip` | Pacote instalável por Magisk/KernelSU |
| `customize.sh` | Patch durante a instalação |
| `service.sh` | Verificação e reaplicação no boot |
| `uninstall.sh` | Restauração condicional |
| `sepolicy.rule` | Permissões necessárias ao remount |
