# SM-A528B: correção do bootloop `bootstrap-apexd-failed`

## Causa comprovada

A variante ext4 da execução #6 montou `/system`, `/vendor`, `/product` e `/odm` com sucesso e executou `Switching root to '/system'`. O reboot seguinte foi solicitado pelo próprio init depois de `SetupCgroups` falhar:

```text
cgroup2: Unknown parameter 'memory_recursiveprot'
cgroup1: Unknown subsys name 'schedtune'
init: Command 'SetupCgroups' ... failed: Failed to setup cgroups: Invalid argument
init: ... apexd-bootstrap ... createProcessGroup ... No such file or directory
init: Got shutdown_command 'reboot,bootloader,bootstrap-apexd-failed'
```

O kernel stock 5.4.254 do pacote A52s não fornece o controlador out-of-tree `schedtune` esperado por parte do userspace donor S711B. O `memory_recursiveprot` já possui fallback no log e não é o evento fatal. Não há evidência de falha de EROFS/ext4, AVB, dm-verity, I/O ou driver como causa desse reboot.

## Alterações específicas

O helper `scripts/patch_a52sxq_compat.py` é executado somente para `SM-A528B`. Ele marca qualquer entrada donor `schedtune` como opcional, redireciona ações `JoinCgroup` para o controlador `cpu`, substitui `STunePreferIdle` por `UClampLatencySensitive` quando disponível e remove atributos `STune*` obsoletos. Se não houver arquivo de cgroups vendor, instala `/vendor/etc/cgroups.json` com `schedtune` opcional, usando o mecanismo de override vendor do Android.

O workflow e o `sixteen.sh` agora leem `STOCK_HAS_SEPARATE_SYSTEM_EXT=FALSE` do target e usam `product,system,vendor,odm`; o conteúdo `system_ext` que já está dentro da árvore `/system` permanece parte do `system.img`, mas não é empacotado como logical partition independente.

O caminho literal incorreto de `debloat.sh` foi corrigido para carregar `Devices/$STOCK_DEVICE/config`. A cópia da `Stock` tree agora é protegida quando o diretório não existe, e o hook Exynos `init.exynos990.rc` é ignorado para o A52s, que recebe init Qualcomm nativo no `vendor.img`.

## Validação local

Foram executados `bash -n` em `sixteen.sh`, `scripts/debloat.sh` e `scripts/QuantumRom.sh`, compilação sintática do helper Python, `git diff --check` e uma fixture com cgroups/task profiles donor-like. A fixture confirmou JSON válido, `schedtune` opcional e perfis redirecionados/removidos. Nenhuma nova execução GitHub Actions foi iniciada por este patch.

A correção é baseada no mecanismo documentado pelo AOSP para controladores cgroup opcionais e na mudança upstream que substituiu `schedtune` por utilclamp:

- https://source.android.com/docs/core/perf/cgroups
- https://android.googlesource.com/platform/system/core.git/+/1b53c2496dca274bd3f8173780a7d6562b5cc016%5E!/

A publicação deste patch não constitui prova de boot. O próximo Artifact deverá ser testado no A52s; somente interface Android ou `sys.boot_completed=1` confirmará o resultado.
