# A52S Camera No-Abort (CSL raise NOP)

Módulo **KernelSU** que elimina o crash (SIGABRT do **main camera provider** (`camera.qcom.so`) **na GCam** quando o `libMOTION.so` (exclusivo da ONE UI stock) não está presente na ROM.

## O que o módulo faz

O crash é causado por um `raise(6)` disparado em em `CSLAcquireDeviceHW+1764` dentro do `camera.qcom.so` quando o acquire do sensor principal (`/dev/v4l-subdev8`) falha.

. O módulo:

1. Detecta o `camera.qcom.so` instalado pelo **SHA-256** do seu binário exato (BuildId `9b26d985843faf46e36d82967f1c1526`);
2. Faz **backup** (`camera.qcom.so.bak`);
3. **NOPeia** a instrução `bl raise(6)` no offset `0xc88b4c` (`49 a1 01 94` → `1f 20 03 d5`);
4. Confere o hash pós-patch (`0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360`);
5. Reaplica o patch a cada **boot** (`service.sh`);
6. Se o hash do binário **não bater** com nenhum dos dois conhecidos — **não mexe em nada** (seguro).

## Arquivos

| Arquivo | Função |
|---|---|
| `a52s-camera-no-abort-csl.kernelsu.zip` | Zip instalável no KernelSU Manager |
| `customize.sh` | Patch + restart do provider (roda na instalação) |
| `service.sh` | Reaplica o patch no boot |
| `module.prop` | Metadados do módulo |
| `sepolicy.rule` | Permissões p/ remount do `/vendor` |

## Instalação

1. Baixe `a52s-camera-no-abort-csl.kernelsu.zip` para o celular;
2. Abra o **KernelSU Manager** → **Módulos** → **⋮** → **Instalar do arquivo**;
3. Selecione o zip e **reboot**;
4. A teste: abra a **GCam (1x)** → câmera **principal (0)** → **1 foto**. Verifique se não há mais crash/tela preta.



## Log

O módulo registra tudo em:

```
/data/adb/modules/a52s_camera_no_abort/patch.log
```

## Desinstalação

Basta remover o módulo no KernelSU Manager → reboot. O `service.sh` não roda mais e o `/vendor` volta ao original no boot (o backup `camera.qcom.so.bak` fica no vendor, mas é inofensivo — pode remover com `su -c 'rm /vendor/lib64/hw/camera.qcom.so.bak'`).

## Nota importante

Este patch **não adiciona** o `libMOTION.so` faltante — ele apenas impede que o provider **aborte** quando o sensor falha. Se a GCam continuar preta por outro motivo, o próximo passo é atacar o próximo elo da cadeia (logcat/tombstone).