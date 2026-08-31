# A52s Camera Vendor 16 Stack

Este módulo substitui, de forma systemless, somente o conjunto de blobs de câmera do vendor A52s 16.0. Ele foi preparado para o SM-A528B/a52sxq que está executando um port com fingerprint de S711B, identificado na captura como `samsung/r11sxxx/a52sxq:16/.../S711BXXSHGZG1`.

A evidência indica que o aparelho usa o módulo principal Samsung `F64ELNGR3SM`/S5KGW1P, enquanto o sistema atual usa uma pilha de câmera de port S23 FE. O log bruto registra `cal_map_version 0x31 vs 0x30`, `No GPIO data`, `seq_val:100 > num_vreg` e NACK CCI. O conjunto deste módulo vem do vendor público A52s 16.0 e inclui `camera.qcom.so`, bibliotecas de sensor, blobs de módulo/calibração, componentes CamX e bibliotecas auxiliares de câmera.

A instalação é **systemless e sem wipe**. O módulo não remonta `/vendor`, não escreve partições e não executa comandos de formatação. Para que o KernelSU-Next exponha módulos em `/vendor`, é necessário que um único metamódulo de montagem, como Mountify, esteja ativo.

Após instalar, reinicie e confirme o log em `/data/adb/modules/a52s_camera_vendor16/activation.log`. O script registra o hash observado de `/vendor/lib64/hw/camera.qcom.so`; não declara sucesso se o overlay não estiver visível. Para rollback, desative ou desinstale este módulo no KernelSU e reinicie. Os arquivos originais não são apagados.

Este módulo é um teste de compatibilidade de vendor, não uma garantia de correção. Se o overlay estiver ativo e a 1x ainda falhar, a causa restante estará no kernel/DTBO/power/CCI ou em uma incompatibilidade entre o vendor A52s e o port de sistema, e o módulo deverá ser removido antes de outro experimento.
