# Registro técnico do port A52s

## Base verificada

- Repositório oficial: `https://github.com/miguelbarretoo/QuantumROM`.
- Fork de trabalho: `https://github.com/vinisg61-coder/QuantumROM`.
- Branch de trabalho inicial: `master`, commit `43faed0`.
- Estrutura de targets existente: `QuantumROM/Devices/<modelo>/`, sem diretório literal `target/` no repositório base.
- Pipeline existente: `scripts/QuantumRom.sh` + `sixteen.sh` + `scripts/flashable_zip.sh` + `.github/workflows/sixteen.yml`.

## Firmware doador da base

O `samloader.log` da base registra o firmware baixado pelo fluxo padrão:

- Modelo: `SM-S711B`
- CSC: `EUX`
- Versão: `S711BXXSFGZE2/S711BOXMFGZE2/S711BXXSFGZE2/S711BXXSFGZE2`
- Arquivo registrado: `SM-S711B_5_20260515123201_3m9mxygnfn_fac.zip.enc4`

A implementação atual de `DOWNLOAD_FIRMWARE` chama `checkupdate` e ignora o argumento opcional de versão, portanto será necessário tornar o uso da versão explícita sem trocar o downloader do projeto. O samloader documenta `download -v <version>`.

## Targets existentes

A target Snapdragon `SM-G781B/config` é o molde mais próximo. Ela usa VNDK/API 30, ABI arm64/armeabi e propriedades ODM; seu comentário de origem é `https://samfw.com/firmware/SM-G781B/ZTO/G781BXXSIHYJ2`.

## A52s / a52sxq

Referências públicas de BoardConfig do a52sxq indicam:

- SoC `SM7325`, plataforma Qualcomm `lahaina`.
- Uma configuração stock/TWRP amplamente usada: `BOARD_SUPER_PARTITION_SIZE=5321523200` e grupo dinâmico de `5317328896` bytes, com partições `system vendor product odm`.
- Outra árvore pública usa `10643046400`, mas é uma configuração alternativa; o valor de 5.321.523.200 bytes será tratado como referência do SM-A528B stock, sujeito a validação final pelo firmware extraído.

## Workflow

O workflow já publica `OUT/QuantumROM*.zip*` via `actions/upload-artifact@v4`. Ele precisa apenas aceitar a versão fixa do firmware e reconhecer a target A52s quando extras nativos forem fornecidos. O workflow atualmente baixa extras apenas para `SM-G780F`, `SM-G980F` e `SM-G988B`.

## Regra de integração

Como o QuantumROM não possui `target/`, a implementação deverá seguir o padrão real e operacional do projeto em `QuantumROM/Devices/SM-A528B/`, com identificador interno `a52sxq` documentado/configurado, sem importar uma árvore externa nem substituir os scripts originais por outro sistema.

## Validação adicional do layout e identidade

A configuração pública de referência do a52sxq confirma o esquema operacional de ROM Samsung usado para esse aparelho:

- `TARGET_FIRMWARE="SM-A528B/BTU/352599501234566"` como referência de firmware nativo A52s.
- `TARGET_PLATFORM="sm7325"`.
- `TARGET_PRODUCT_SHIPPING_API_LEVEL=30`.
- `TARGET_SUPER_PARTITION_SIZE=10643046400`.
- `TARGET_QTI_DYNAMIC_PARTITIONS_SIZE=10638852096`.
- Partições dinâmicas: `system`, `vendor`, `product`, `odm`.
- Política DVFS: `dvfs_policy_sm7325_xx`.
- Política SSRM/SIOP: `siop_a52sxq_sm7325`.
- ABI eMMC/slot devem permanecer não-A/B no formato de target Samsung existente; a definição final será mantida compatível com o `config` do QuantumROM.

A consulta confirma que o valor de 10.643.046.400 bytes é o layout de referência para o fluxo de ROM do a52sxq; o valor de 5.321.523.200 bytes veio de uma configuração alternativa de recovery e não será usado no empacotamento QuantumROM.

## Autorização GitHub

A primeira tentativa de código expirou. Um segundo código foi gerado, validado pelo My Browser e a tela final do GitHub exibiu a permissão `Update github action workflows`. Após a confirmação do usuário, o terminal foi liberado para concluir o polling do OAuth.

## Estado do segundo OAuth

O novo código `1F9C-E89F` foi aceito pelo GitHub e chegou à tela final `Authorize GitHub CLI`, que lista `Update github action workflows`. As tentativas de clique por CDP e teclado não mudaram a URL; o polling do terminal foi liberado após o Enter inicial, portanto o próximo passo é verificar diretamente se o token persistido foi atualizado.

## Auditoria do erro lpmake

A execução 32971768929 confirmou a falha real em `scripts/QuantumRom.sh`: após adicionar `odm`, `product`, `system` e `vendor`, o QuantumROM chamou o `lpmake` com `--image` mas sem `--sparse`. A ferramenta emite quatro avisos `Invalid sparse file format at header magic` ao sondar os inputs raw e termina com `sparse_file_write failed (error code -22)`; como o retorno de `BUILD_SUPER_IMG` não era verificado por `sixteen.sh`, o empacotador ainda gerava um ZIP.

A implementação de referência do próprio fornecedor (`LonelyFool/lpunpack_and_lpmake`, `partition_tools/README.md`, `lpmake.cc` e `lib/liblp/images.cpp`) confirma que `--sparse` é o modo de saída necessário quando `--image` é usado, e que cada entrada pode ser normal ou Android sparse. A correção final mantém imagens EROFS/ext4 raw — evitando a dupla importação que provocava `-22` em imagens grandes —, converte apenas entradas que já sejam Android sparse com `simg2img`, chama `lpmake --sparse`, converte a saída com `simg2img` para o `super.img` raw que o ZIP flashável grava diretamente no bloco e rejeita qualquer falha ou divergência de tamanho.

Para o SM-A528B, os limites configurados são `STOCK_SUPER_PARTITION_SIZE=10643046400` e `STOCK_FLASHABLE_ZIP_GROUP_SIZE=10638852096`; ambos são divisíveis por 512 e 4096, e o grupo é 4.194.304 bytes menor que o super, portanto não estoura a tabela dinâmica nativa. A config mantém `vendor` e `odm` nativos. Os testes locais com EROFS raw, EROFS Android sparse e as quatro dimensões reais do log passaram por `lpmake --sparse`, `simg2img` e `lpunpack`; o `super.img` raw resultante tem exatamente 10.643.046.400 bytes.

## Rerun da correção

A correção do `lpmake` e a propagação de erro foram publicadas na branch `port/a52sxq-clean` no commit `15b7be7`. O formulário `workflow_dispatch` reabriu com `master` como ref padrão; o rerun deve ser executado explicitamente na branch `port/a52sxq-clean`, mantendo `SM-A528B`, `SM-S711B/EUX`, a versão doadora exata e `erofs`.

## Rerun #2 e correção final

A execução `32978169663` passou por download, extração e ajustes de partições, mas falhou em `Start Rom Build For SM-A528B` com `sparse_file_write failed (error code -22)`. O log mostrou que a falha ocorria após converter imagens EROFS grandes para sparse antes de reimportá-las. Testes locais com EROFS raw, EROFS sparse, quatro dimensões reais e `lpunpack` mostraram que o caminho robusto é manter EROFS/ext4 raw como input, validar apenas Android sparse existente com `simg2img`, usar `--sparse` na saída do `lpmake` e converter o super final para raw.

A implementação final foi publicada na branch `port/a52sxq-clean` no commit `bee3183`, e o novo rerun deve ser disparado na mesma branch com `SM-A528B`, `SM-S711B/EUX`, firmware doador fixo e `erofs`.

## Execução #2 e preparação da #3

A execução `32978169663` falhou em `Start Rom Build For SM-A528B` com `sparse_file_write failed (error code -22)` após a conversão prévia das imagens EROFS grandes. A correção final no commit `bee3183` remove essa dupla conversão: inputs EROFS/ext4 permanecem raw, inputs Android sparse são validados com `simg2img`, `lpmake` gera sparse e o resultado é convertido para raw antes do empacotamento. O formulário do Actions está aberto para executar a branch `port/a52sxq-clean` com os inputs do QuantumROM.

## Execução #3

O disparo via CLI foi bloqueado por HTTP 403, então a execução será iniciada pelo My Browser autenticado. O formulário está na branch `port/a52sxq-clean`, commit `bee3183`, com `SM-A528B` como stock, `SM-S711B/EUX` como doador, versão exata `S711BXXSFGZE2/S711BOXMFGZE2/S711BXXSFGZE2/S711BXXSFGZE2` e saída `erofs`.

## Execução #4 e causa definitiva do -22

A execução `33012257188`, commit `bee3183`, saiu de `queued` e completou sem erros o checkout, validação do SM-A528B, instalação de dependências, download/extract do doador SM-S711B/EUX fixado, download dos extras nativos A52s, ajustes de partições, de-bloat, patches e geração das quatro imagens. Ela falhou somente ao escrever o `super.img`, com `sparse_file_write failed (error code -22)`, antes da etapa de ZIP; o workflow abortou corretamente e não publicou Artifact.

A reprodução local com as dimensões reais e arquivos zerados passou. A reprodução com um `system.img` não-zero de 4.557.168.640 bytes falhou com o mesmo -22 no `lpmake` original, tanto com `--sparse` quanto sem `--sparse`. A causa é o overflow do campo interno `backed_block.len`, declarado como `unsigned int` na implementação Android 11 bundled de `libsparse`. Como o `system` excede 4 GiB, a coalescência dos blocos de 4096 bytes transborda antes do split de 64 MiB; o writer recebe um comprimento inválido e devolve `EINVAL`.

A correção mínima foi aplicada no upstream `LonelyFool/lpunpack_and_lpmake` Android 11, commit `7ec860cfa95ed83dec579ab0459aad1c35ad48e4`: `backed_block.len` e `backed_block_len()` foram ampliados para `uint64_t`, mantendo os limites de chunk e o formato sparse originais. O binário estático rebuilt passou a gerar o sparse super, `simg2img` produziu raw de exatamente `10.643.046.400` bytes e `lpunpack` recuperou `odm`, `product`, `system` e `vendor` nos tamanhos esperados. O binário corrigido foi instalado somente em `bin/lp/lpmake`; o patch e a proveniência estão documentados em `bin/lp/backed_block_64bit.patch` e `bin/lp/LPMMAKE_BUILD.md`.
