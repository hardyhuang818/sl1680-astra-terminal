# Astra 语音模型的提供方式

`astra-voice_1.0.bb` **不打包模型**。ASR/TTS/LLM 合计约 2 GB，不适合进 git，
也不适合进 Yocto 的 `files/`（每次 `do_unpack` 都要拷一遍）。

模型固定放在 `/home/voice/` 下，路径**写死在 `astra_voice.c` 里**（`const char *dir = "/home/voice"`），
改路径要同时改代码。

---

## 一、装完镜像后要补的东西

| 板端路径 | 内容 | 大小 |
|---|---|---|
| `/home/voice/sv/` | SenseVoice ASR（int8）+ silero VAD | 229 MB |
| `/home/voice/matcha/` | Matcha TTS 声学模型 + vocos 声码器 + espeak-ng-data | 144 MB |
| `/home/voice/tts/` | VITS TTS（备用发音人） | 234 MB |
| `/home/voice/llm/qwen2.5-0.5b-instruct-q8_0.gguf` | 断网兜底的本地小模型 | 676 MB |
| `/home/voice/bin/` | `llama-completion`、`sherpa-onnx-*` 命令行工具 | 约 230 MB |
| `/etc/astra/llm.conf` | 云端 key（从 `llm.conf.sample` 复制后填写，`chmod 600`） | — |

`/home/voice/llm/` 下另有 `gemma-3-270m-it-Q8_0.gguf` 和
`qwen2.5-0.5b-instruct-q4_k_m.gguf`，是选型时留下的，**当前没有任何服务在用**，
恢复时可以不灌。

## 二、精确清单（校验用）

见 `MODEL_MANIFEST.txt`（与本文件同目录）。里面是 2026-07-23 板上实际运行版本的
sha256、字节数；目录项（`espeak-ng-data/`、`dict/`）给的是按文件名排序后 tar 流的哈希，
用来判断整份数据是否被动过。

恢复后核对：

```bash
sh tools/model_manifest.sh > /tmp/now.txt && diff /tmp/now.txt MODEL_MANIFEST.txt
```

## 三、来源

`sv/`、`matcha/`、`tts/` 都是 sherpa-onnx 官方发布的预训练模型包，从 next-gen Kaldi
的模型仓库下载后解压。**本仓库没有记录当初下载的具体 release URL**，要重新拉取请按
`matcha/README.md`、`tts/README.md`（模型包自带）里的说明找对应版本，下载后用第二节的
manifest 核对哈希，不一致就不是同一份。

`bin/` 下的可执行文件是在 WSL 里交叉编译的（`astra-xiaozhi/build-*.sh`），
不由任何 recipe 产出。

## 四、许可证

⚠️ `matcha/espeak-ng-data/`（18 MB、355 个文件）来自 **espeak-ng，GPLv3**。
它随 Matcha TTS 的中文前端一起使用，会把 GPLv3 传染到整条链路。
产品化之前必须解决——要么换掉不依赖 espeak-ng 的前端，要么接受 GPLv3 开源义务。
`tts/LICENSE` 是 VITS 模型自己的许可，需单独确认是否允许商用。

细节见项目 memory `tts-licensing-blockers`。
