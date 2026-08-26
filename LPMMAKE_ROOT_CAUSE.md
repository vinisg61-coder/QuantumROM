# Diagnóstico confirmado do `lpmake -22`

A execução #4 (`33012257188`) processou firmware, patches e geração das imagens sem erro. O log registrou quatro imagens lógicas alinhadas: `odm=614400`, `product=828370944`, `system=4557168640` e `vendor=985165824` bytes. O super configurado é `10643046400` bytes e o grupo dinâmico é `10638852096` bytes; o payload alinhado permanece abaixo do grupo.

A reprodução local com os mesmos tamanhos e arquivos zerados passou. A reprodução com um `system.img` não-zero de `4557168640` bytes falhou com o mesmo `sparse_file_write failed (error code -22)`, tanto com `--sparse` quanto sem `--sparse`. Isso elimina o layout do super e o modo de saída como causa primária.

A origem está na implementação Android 11 bundled de `libsparse` usada pelo `lpmake`: `backed_block.len` é `unsigned int` (32 bits). O `ImageBuilder::AddPartitionImage` adiciona blocos de 4096 bytes de uma imagem contínua; ao coalescer o `system.img` não-zero, o comprimento acumulado ultrapassa 4 GiB e transborda para zero/valor incorreto. O writer então tenta processar um bloco inválido; no Linux, o `mmap` com comprimento zero retorna `EINVAL`, que aparece como `sparse_file_write failed (error code -22)`.

Conclusão: a correção de entrada raw/sparse e `--sparse` estava correta, mas não podia resolver o overflow interno para a partição `system` real do S711B. A correção necessária é atualizar/recompilar apenas o `lpmake`/`libsparse` bundled a partir do upstream Android 11, alterando o comprimento interno de backed blocks para 64 bits ou impedindo coalescimento acima de `UINT_MAX`, mantendo o pipeline QuantumROM e o super final raw de 10.643.046.400 bytes.

Nenhum Artifact da execução #4 é válido; a etapa de ZIP foi pulada após a falha, como desejado.
