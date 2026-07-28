# 从零复现构建环境（官方 SDK + 本仓库）

本仓库**不 fork** Synaptics 官方 SDK——上游保持原样、版本钉死，我们的全部修改装在自己的 Yocto 层 `meta-dlsdk/` 里（含 TD7800 内核补丁，以 bbappend 形式打在官方 linux-syna 上）。

## 上游版本（钉死，勿漂移）

| 组件 | 来源 | 版本 |
|---|---|---|
| Astra SDK | https://github.com/synaptics-astra/sdk | tag **`scarthgap_6.12_v2.3.0`** |
| poky | git.yoctoproject.org/poky | yocto-5.0.9（SDK 自带） |
| meta-synaptics | github.com/synaptics-astra/meta-synaptics | a0344af（SDK 自带） |

## 四步复现

```bash
# 1) 官方 SDK（钉版本）
git clone --branch scarthgap_6.12_v2.3.0 https://github.com/synaptics-astra/sdk ~/sdk
cd ~/sdk && git submodule update --init --recursive 2>/dev/null || true   # 子层若非 submodule 则按官方 README 初始化

# 2) 本仓库
git clone <本仓库地址> ~/sl1680-astra-terminal

# 3) 接层（幂等）
~/sl1680-astra-terminal/tools/setup_sdk.sh ~/sdk

# 4) 构建
cd ~/sdk && source poky/oe-init-build-env build-sl1680 && bitbake astra-media
```

产物：`tmp/deploy/images/sl1680/SYNAIMG/`（约 2.5GB 烧录包）。

## 两个必读的坑

1. **DLSDK 二进制不在仓库里**（DisplayLink NDA，2026-08-01 后有公开版）。构建 dl-face/dl-clock 前需把二进制放入
   `meta-dlsdk/recipes-graphics/dlsdk/files/`，所需文件清单与 sha256 见
   `meta-dlsdk/recipes-graphics/dlsdk/BINARIES_MANIFEST.txt`。不需要 DL7400 功能时可在 local.conf 置
   `ASTRA_TERMINAL_PACKAGES = ""` 跳过。
2. **约 2GB 语音模型不在镜像里**，烧录后单独灌 `/home/voice/`，见 `meta-dlsdk/recipes-ai/astra-voice/files/README_models.md`。

## 与板端的关系

板子是真相：改完板子必须回灌仓库并跑 sha256 对账（`tools/export_live.sh`）。版本流水见 `meta-dlsdk/VERSION`，逐日改动见 `backups/CHANGELOG.md`。
