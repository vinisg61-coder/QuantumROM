# Run #6 — evidência de filesystem ext4

A execução é `https://github.com/vinisg61-coder/QuantumROM/actions/runs/33021829136`, job `98353804165`, branch `port/a52sxq-clean`, commit do checkout `296dbb8`. O formulário foi enviado com `OUTPUT_FILESYSTEM=ext4`.

O console do passo `Start Rom Build For SM-A528B` mostra explicitamente, entre as linhas 1206–1228:

```text
Generating fs_config for partition: odm
Generating file_contexts for partition: odm
Building ext4 image: /home/runner/work/QuantumROM/QuantumROM/OUT/odm.img
Size: 4349952
Block size: 4096
LabeI: odm
Created filesystem ...
Resizing the filesystem ...
```

O mesmo console mostra que o conteúdo nativo foi extraído antes e que `odm.img` foi reconstruído pelo `BUILD_IMG`, em vez de simplesmente ser injetado como EROFS. A busca do console por `Building ext4 image` indica 1/4 ocorrências visíveis; as demais devem corresponder a `product`, `system` e `vendor`.

Também foram observados anteriormente no mesmo job:

```text
Using stock vendor.img from SM-A528B/extra
Using stock odm.img from SM-A528B/extra
odm.img Detected ext4. Size: 4349952 bytes. Extracting...
product.img Detected erofs. Size: 1463422976 bytes. Extracting...
system.img Detected erofs. Size: 7183728640 bytes. Extracting...
vendor.img Detected ext4. Size: 1599823872 bytes. Extracting...
```

Essas linhas demonstram que a origem de vendor/odm é nativa do A52s e que a variante ext4 reconstrói o filesystem das partições a partir do conteúdo extraído. A validação final do host foi concluída: `lpmake` gerou um `super.img` bruto válido, o ZIP foi compactado com êxito e o Artifact foi publicado. A única validação pendente é o boot real no aparelho.

## Comparação de tamanho com a execução EROFS #5

A execução EROFS #5 (`33016788315`) publicou Artifact de `5,271,743,294` bytes; a execução ext4 #6 (`33021829136`) publicou `5,089,636,786` bytes. A diferença é de `182,106,508` bytes (aproximadamente `173.67 MiB`, ou `3.45%`).

A comparação do log mostra que o `super.img` bruto permaneceu com `10,643,046,400` bytes nas duas execuções. Na #5, o `system` adicionado ao super tinha `4,557,168,640` bytes e o `product` `828,370,944` bytes; na #6 ext4, `system` tinha `6,831,284,224` bytes e `product` `1,306,435,584` bytes. Portanto, o Artifact menor decorre da compressão externa do ZIP sobre os blocos livres/zerados das imagens ext4, e não de um super menor ou de partições omitidas.

O ZIP interno da #6 foi finalizado com `Everything is Ok`, e o Artifact foi publicado sem expiração, ID `9628066147`.
