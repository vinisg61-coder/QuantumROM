# lpmake bundled do QuantumROM

O `lpmake` deste diretório é compilado estaticamente a partir de [LonelyFool/lpunpack_and_lpmake](https://github.com/LonelyFool/lpunpack_and_lpmake), branch `android11`, commit `7ec860cfa95ed83dec579ab0459aad1c35ad48e4`.

Foi aplicado somente o patch `backed_block_64bit.patch`. A implementação Android 11 de `libsparse` acumulava o comprimento interno de um `backed_block` em `unsigned int`. Ao receber uma partição lógica `system` maior que 4 GiB, a coalescência dos blocos de 4096 bytes sofria overflow, criando um comprimento inválido e terminando em `sparse_file_write failed (error code -22)`. O campo acumulado e seu getter agora usam `uint64_t`; os chunks individuais continuam limitados pelo `backed_block_split()` existente antes da escrita, sem alterar o formato Android sparse ou as chamadas do QuantumROM.

A recompilação foi feita com o `make.sh` upstream. O binário resultante é estático, x86-64, e foi instalado somente em `bin/lp/lpmake`; `lpunpack` e os scripts originais do QuantumROM não foram substituídos.

## Validação local

Com as quatro dimensões registradas no runner — `odm=614400`, `product=828370944`, `system=4557168640` e `vendor=985165824` — um payload `system.img` não-zero reproduziu o `-22` no binário anterior. O binário rebuilt gerou um Android sparse super, `simg2img` converteu a saída para raw com exatamente `10643046400` bytes, e `lpunpack` recuperou as quatro partições com os tamanhos esperados.

O workflow continua chamando `BUILD_SUPER_IMG` no mesmo ponto e continua convertendo a saída sparse para raw antes do `flashable_zip.sh`, que grava o `super.img` diretamente no bloco. A correção não altera o firmware doador, o kernel/boot/dtbo, vendor/odm nativos, de-bloat, patches Smali/framework ou a estrutura geral do QuantumROM.
