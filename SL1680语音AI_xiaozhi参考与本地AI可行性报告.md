# SL1680 语音 AI：xiaozhi 参考价值 与 本地 AI 可行性报告

> 日期：2026-07-17　　板子：Synaptics Astra SL1680 (dolphin RDK) @ 192.168.5.126
>
> **证据分级**：🟢**实测**＝我在这块板子上跑出来的数字｜🔵**已核实**＝拉取一手源码/官方文档逐字确认｜🟡**推断**｜🔴**待实测**
>
> 本报告不提供任何没有出处的性能数字。

---

## 〇、一句话结论

> **xiaozhi 是一份优秀的协议规范和产品参考，不是可移植的代码库 —— 当 RFC 读，别当 SDK 用。**
>
> **SL1680 本地跑 ASR 没问题；TTS 要换模型；LLM 只能做"意图分类"不能做"对话大脑"；声音克隆必须联网。**
>
> **SyNAP NPU 对语音基本帮不上忙 —— 但它对视觉是真的强。产品叙事应该改成："NPU 跑视觉感知，CPU 跑语音"。**

---

## 一、能不能参考 xiaozhi-esp32？

### ✅ 值得参考（高价值）

| 项 | 说明 | 证据 |
|---|---|---|
| **WebSocket 语音协议** | 整个项目对我们最有用的东西。设计很干净：上行只有 4 种消息（hello / listen / abort / mcp），裸 Opus 二进制帧 | 🔵 文档 + `websocket_protocol.cc` 代码级双重确认 |
| **产品形态已被验证** | 28k stars、今天仍在 push。"唤醒→VAD→ASR→LLM→TTS→回传播放"这条链在真实产品里跑得通，交互状态机不用从零设计 | 🔵 |
| **11 个设备状态机** | 抄枚举和迁移表，换掉 ESP_LOG 即可 | 🔵 |
| **MCP 暴露设备能力** | 我们有 3 块屏 + 客户输入，用 MCP 把"切换屏幕""显示表单"暴露给 LLM，是已验证的模式 | 🔵 |
| **xiaozhi-esp32-server 的 config.yaml** | 当**选型 checklist** 读。里面 SherpaASR 段用的**正好是我们这套模型**：`model_type: sense_voice` + `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17` | 🔵 逐字核实 |

### ❌ 不能照搬（会浪费时间）

| 项 | 为什么 |
|---|---|
| **ESP-SR 唤醒词 (WakeNet)** | Espressif 闭源、绑死 ESP32-S3。**根本不存在 aarch64 版本** 🔵 |
| **AFE 音频前端 (AEC/NS)** | 同上，ESP-DSP 绑定。SL1680 上 AEC 必须自己解决 |
| **Opus 编码参数** | 它的 `complexity = 0` 是 MCU 上的极限压榨。照抄 = **无谓自我削弱**。SL1680 应上调到 5–10 |
| **MQTT+UDP 传输** | **别碰**。文档里 AES-CTR nonce 的描述**是错的** —— 代码实际把 `payload_len` 写进了 nonce offset 2，文档漏了。按文档实现必然解密失败。走 WebSocket 完全规避 🔵 代码逐行比对 |
| **整个 C++ 应用层** | 连"纯逻辑"的 `device_state_machine.cc` 都 `#include <esp_log.h>`。没有一个文件能原样编译 🔵 |

### ⚠️ 只读不抄

- **py-xiaozhi**（Python 客户端，MIT）：**读它怎么实现协议、怎么用 sherpa-onnx 做 KWS**。但别指望跑起来 —— 依赖含 `pynput`(需 X11，Astra 默认是 **Weston/Wayland**，可能直接 import 失败)、`sounddevice`(要 PortAudio)、`soxr`(要编译)。它验证过的 RPi/Jetson **全是完整 Debian userland**，和 Yocto 不是一回事。
- **100askTeam/xiaozhi-linux**（C 实现，更贴合）：**两条红线** —— GitHub API 检测不到任何 license 字段（**商用有法律风险**）；`pushed_at = 2025-07-08`，**一年多没更新**。🔵

### 两个必须修正的实现细节 🔵

1. **`features` 字段要照发 `{"mcp": false}`，不要整个省略** —— 参考设备代码里是无条件上报的，没有任何真实服务端验证过省略后的行为。
2. **下行采样率是 24000 Hz，不是 16k** —— 上行 16k / 下行 24k，**需要重采样**。

---

## 二、板上实测数据（本次新增）

### 2.1 CPU：这是全部结论的基石 🟢

```
CPU part        : 0xd09          = Cortex-A73
CPU architecture: 8              = ARMv8.0-A
Features        : fp asimd aes pmull sha1 sha2 crc32 cpuid

✅ asimd    (NEON)
❌ asimddp  (dot product, ARMv8.2 起)
❌ i8mm     (int8 矩阵乘, ARMv8.6 起)
❌ fphp / asimdhp (fp16)
```

> **这颗 A73 是纯 ARMv8.0，没有任何 int8/fp16 加速指令。**
> 几乎所有"int8 量化提速 2–4×"的经验值都建立在 SDOT 之上 —— 在这块板子上拿不到。

### 2.2 TTS 实测：量化是负优化 🟢

| 模型 | 线程 | 总耗时 | 音频时长 |
|---|---|---|---|
| model.onnx (fp32, 170MB) | 4 | **21.5s** | 4.86s |
| model.int8.onnx (53.5MB) | 4 | **41.7s** ← 慢 1.9× | 4.82s |
| model.onnx (fp32) | 2 | 28.3s | 4.86s |
| model.int8.onnx | 2 | 47.0s ← 慢 1.7× | 4.99s |

**int8 比 fp32 慢近一倍，两种线程数下一致复现。**

与 ONNX Runtime 官方文档的倾向性吻合 🔵：
> "quantization has overhead... **it is not rare to get worse performance on old devices**"，且明确说受益的是"**Arm-based processors with dot-product instructions**"—— 正好排除 A73。

### ⚠️ 但这条**不能推广到所有模型** —— 我一度推广了，是错的 🟢

后续实测 SenseVoice（同一 onnxruntime、同一板子、4 线程）：

| 模型 | fp32 | int8 | 方向 |
|---|---|---|---|
| vits-melo TTS | 21.5s | **41.7s** | int8 **慢 1.9×** ❌ |
| **SenseVoice ASR** | RTF 0.291 / RSS 1287MB | **RTF 0.201 / RSS 393MB** | int8 **快 1.45×**、省 3.3× 内存 ✅ |

**同一颗 CPU，两个模型的量化收益方向完全相反。**

我最初只测了 TTS 就写下"A73 无 dotprod ⇒ 量化是负优化"这条 CPU 级普适规律 —— **这是过度泛化**。ORT 那句话是**倾向性，不是定律**。

> **正确的规则：量化效果因模型而异，每个模型都要自己测 fp32 vs int8。**
> 已定结论：**SenseVoice 用 int8**（快且省内存）｜**vits-melo 用 fp32**。
> llama.cpp 的 Q4 是否受影响 —— 🔴 **待实测，不要假设**。

机理推测（🟡 未验证）：VITS 有大量卷积/flow 层，动态量化插满 QDQ 且部分算子无 int8 内核要回退；SenseVoice 以 matmul 为主，NEON int8 乘加吞吐仍高于 fp32。

### 2.3 拆开"加载"与"合成"—— 修正一个我之前报错的数字 🟢

```
fp32  1个字  → 11.38s (音频 0.28s)   ⇒ 模型加载 ≈ 11.1s
fp32  长句   → 21.41s (音频 5.02s)   ⇒ 纯合成 ≈ 10.3s / 5.02s = RTF 2.05
```

> **我之前报的 "RTF 4.6" 是错的 —— 把 11 秒的模型加载算进了合成时间。真实合成 RTF ≈ 2.05。**

两个直接后果：
1. **进程必须常驻**。每次重新加载白扔 11 秒，比模型慢本身更致命。
2. 差距没那么大：从 2.05 到实时只需 ~2×，不是 ~5×。

**交叉验证** 🔵：melo 官方公布树莓派4 四线程 **RTF 2.518**。我们实测 **2.05**，略好于 RPi4 —— 两个独立来源互相印证。

### 2.4 其它已验证的能力 🟢

| 能力 | 状态 |
|---|---|
| 麦克风 / 喇叭 (Razer Kraken, card 2) | ✅ 正常 |
| **SenseVoice ASR 速度** | ✅ **RTF 0.197（4线程）= 5× 实时余量。1线程 0.626 / 2线程 0.338。ASR 不是瓶颈** |
| SenseVoice 离线 ASR 准确度 | ✅ 官方音频完美识别 |
| Silero VAD + SenseVoice 实时链路 | ✅ 能启动进入监听 |
| TTS 中文合成 | ✅ 闭环验证：合成→再识别，中文一字不差 |
| TTS 英文合成 | ⚠️ 质量差（"Hello, this is a test" → "hel,V say the test"） |
| /dev/synap | ✅ 存在 |

---

## 三、SyNAP NPU：诚实的答案

### 3.1 结论：**对语音 AI 几乎帮不上任何忙**

不是"需要投入工作量去集成"，而是**架构层面尚未被证明可行，且厂商自己选择了不走这条路**。

### 3.2 最有力的证据：Synaptics 自己的选择 🔵

逐个读了 `synaptics-synap/examples` 仓库（2026-07-07 还在推）：

| 文件 | 运行时 | 硬件 |
|---|---|---|
| `vision/image_class.py` | `synapRT.pipelines` + `model.synap` | **NPU** |
| `speech_to_text/moonshine.py` | `onnxruntime.InferenceSession()`，**无 providers 参数** | CPU |
| `text_to_speech/piper.py` | `os.system('... | piper ...')` | CPU |
| `llm/gemma.py` | `llama_cpp.Llama`, `gemma-3-270m-it-Q8_0.gguf` | CPU |
| `embeddings/minilm.py` | `llama_cpp.Llama(n_threads=4)` | CPU |

README 逐字：**"Vision examples leverage NPU and other examples leverage CPU."**

> **MiniLM 是纯 transformer encoder，比 SenseVoice 还小。Synaptics 自己都用 llama.cpp 在 4 个 A73 核上跑，没上 NPU。**

再补一刀：Synaptics 自家参考设计 `on-device-ai-assistant`（**已于 2025-05-09 archived**）逐字：
> "Context-specific Q&A matching using an **encoder-only** language model (**future support for small LLM planned**)"

**厂商在自己的旗舰语音参考设计里，刻意避开了 decoder LLM。**

### 3.3 算子不是问题，动态 shape 才是 🔵

需要澄清一个误解：**SyNAP 的算子表其实覆盖了 transformer 所需的全部基础算子** —— MATRIXMUL ✅、SOFTMAX ✅、LAYER_NORM ✅、GELU ✅、FULLY_CONNECTED ✅。所以"算子不支持"**不是**拒绝 SyNAP 的正当理由。

**真正卡死的是四条**：

1. **固定 shape**。`.synap` 模型全文零次提及 dynamic shape / KV cache，batch **固定为 1**。而 SenseVoice 的变长音频、VITS 的变长文本→变长音频、LLM 的 KV cache 增长，**全部是动态 shape**。
2. **强制量化**。文档原文："in order to efficiently run a model on the NPU HW **it has to be quantized**"。而我们刚实测证明**量化在这块板子的 CPU 上是负优化** —— NPU 量化则是另一回事，但要先转换成功。
3. **无自动 CPU fallback**。
4. **sherpa-onnx 没有 SyNAP provider**。provider enum 只有 8 项：`cpu/cuda/coreml/xnnpack/nnapi/trt/directml/spacemit`。

> ⚠️ **陷阱**：`StringToProvider()` 对未知字符串**静默回退 CPU**，只打一行日志。写 `--provider=synap` **不会报错，会安静地跑在 CPU 上。**

### 3.4 GPU 路径：源码级证伪 🔵

SL1680 **确实有 GPU**（Imagination PowerVR Series9XE **GE9920**）—— 我之前说"无 GPU"是错的。但它救不了我们：

`runtime/lib/synapnb/src/predictor_onnx.cpp` 的 `load_model()` **只解析 `log_level` 和 `num_threads`**，**从不解析 `gpu`**，且 buffer 绑死 CPU：
```cpp
Ort::MemoryInfo mem_info = Ort::MemoryInfo::CreateCpu(...);
```
而转换器 `onnx_converter.py` **却会写出** `delegate_string = "onnx gpu=1"`。

> **`delegate: gpu` + ONNX 模型 = 静默跑在 CPU 上。这是 SyNAP 自身的 bug。做对照实验时千万别用它，会给假结果。**

GE9920 本身：Imagination 官方 = **"64 FP32 FLOPs/Clock"**，定位"DTV 入门级/穿戴/智能家居"。**是入门级图形 GPU，不是计算加速器**，而且还要驱动我们那 3 块屏。

### 3.5 ★ NPU 真正的用武之地：视觉

benchmark 页 12 个模型**全是视觉**（mobilenet / yolov5 / yolov8s-pose / posenet / resnet / unet / deeplab_v3_plus…），全部有官方实测。

> ### 产品建议：把"7.9 TOPS NPU 价值"的叙事，从**"NPU 跑语音"**改成**"NPU 跑视觉感知 + CPU 跑语音"**。
>
> 这样既**诚实**，又**真的用上了芯片**，而且是一个**更好的 kiosk 产品** —— 人走近自动唤醒，体验远好于喊"astra"。
>
> **而且罗技 C920 明天就到。**

---

## 四、架构对比

| 维度 | xiaozhi 原生<br>(ESP32+云) | SL1680 全本地 | **SL1680 + 自建服务端**<br>（推荐起点） |
|---|---|---|---|
| **唤醒词** | ESP-SR（芯片绑定，不可移植） | sherpa-onnx KWS (CPU) | 同左 |
| **VAD** | AFE（芯片绑定） | Silero ONNX ✅ 已上板 | 同左 |
| **ASR** | 云端 | SenseVoice ✅ 已上板 | 板上或同机 |
| **LLM** | 云端 | ❌ 只能 270M–600M 级 | 云 API 或外部 llama-server |
| **TTS** | 云端 | ⚠️ RTF 2.05，需换模型 | 可选 |
| **声音克隆** | 仓库无此概念 | ❌ 端侧实时不现实 | ✅ 离线预生成 |
| **联网依赖** | 强（断网即哑） | 无 | 取决于 LLM |
| **隐私 / 音色可控** | 语音出境 | 完全可控 | 可控 |
| **主要风险** | 商用不可接受 | TTS + LLM 双重不可行 | Yocto 上部署 Python 栈 |

### 关于 xiaozhi-esp32-server 的一个关键澄清 🔵

> **它进程内真正跑模型的只有 VAD + ASR。**
> 所有"本地 TTS / 本地 LLM"在配置里**全是 HTTP 客户端**：FishSpeech → `http://127.0.0.1:8080/v1/tts`、Ollama → `http://localhost:11434`、LMStudio → `http://localhost:1234/v1`。

两个后果：
1. **"xiaozhi-server 太重跑不动 SL1680"论证对象错了** —— 它自己就是 SileroVAD + SenseVoice 的开销，**正好是我们板上已跑通的两个模型**。
2. **它对 TTS 瓶颈既不加重也不解决** —— 别指望从这个仓库找 TTS 答案。

**接 llama.cpp 是文档化模式的直接套用**：config 里 `LMStudioLLM` 就是 `type: openai` + `url: http://localhost:1234/v1` + 假 api_key。换个 URL 指向 llama-server 即可，不是 hack。

---

## 五、三个已知问题的解法

### 5.1 TTS 太慢（真实 RTF 2.05）

**xiaozhi 这两个仓库对此提供【零】帮助** —— 设备端只解 Opus，服务端只是 HTTP 转发。

按投入产出排序：

| # | 方案 | 判断 |
|---|---|---|
| 1 | **进程常驻** | 🟢 **立刻做**。省掉每次 11.1s 加载，这是白捡的 |
| 2 | ~~int8 量化~~ | 🟢 **已实测证伪，放弃** |
| 3 | **Piper 中文 (huayan-medium)** | **Synaptics 官方 Astra 示例就是 Piper**，模型远小于 melo。🔴 无中文 RTF 公开数据，待实测 |
| 4 | **matcha-icefall-zh-baker** | RPi4 官方 **RTF 0.391**（4线程 fp32），有 2.5× 余量。⚠️ **但 Baker 数据集非商用 —— kiosk 商业产品的法务硬伤** |
| 5 | **TTS 上云** | 联网模式下最省事 |

### 5.2 唤醒词 "astra" —— 未解决，且我要说清楚不确定性

**当前真实状态** 🟢：

| 音频 | 说话人 | KWS 结果 |
|---|---|---|
| en_0.wav（"...the yellow lamps would **light up** here and there..."） | **母语英语 + 录音室** | ✅ 检出 LIGHT_UP |
| 你的录音（"LIGHT UP + 三遍 astra"） | 中文母语者 + 办公室 | ❌ 阈值降到 0.05 仍无检出，降噪后也无 |

**已排除**：
- ❌ token 空间问题 —— 实测 `AE1=7, S=57, T=59, R=56, AH0=9` **全部存在**，263 个 token 含 45 个 ARPAbet
- ❌ 引擎坏了 —— 官方音频正常检出

**旁证**：SenseVoice 把你的 "LIGHT" 听成 "**not**" —— l/n 混淆是典型中文口音特征。

**但我不下结论** —— 这里有**两个混杂因素**（口音、信噪比），现有数据分不开。我用 TTS 合成做对照的尝试**无效**，因为 melo 的英文发音本身就差。

**候选解法**（按推荐度）：
1. **改用摄像头感知唤醒**（NPU 真能加速，UX 更好，C920 明天到）
2. **换中文唤醒词** —— 这个 KWS 模型有拼音 token，且匹配说话人母语
3. **openWakeWord** —— 用你实际的发音样本训练
4. **"hey astra"** —— 双音节，业界唤醒词都是双音节以上（短词误触发率高）

### 5.3 声音克隆

🔵 **端侧实时不现实**（3.28GB + 4×A73 无 dotprod，零证据支撑）。
**唯一稳妥路径：PC 上克隆 → 导出音色 → 板上推理，或走云端。**

---

## 六、内存预算 🟢

```
物理 4GB LPDDR4x → carveout 后 Linux 可见 3.28GB → 实测可用 ≈ 2.9GB

SenseVoice int8   239 MB
TTS (melo fp32)   170 MB
Silero VAD        0.6 MB
KWS               5.4 MB
────────────────────────
语音栈小计       ≈ 415 MB
剩余给 3 屏 UI + LLM ≈ 2.5 GB
```

---

## 七、路线图

### 第一步（最快见效，本周）
1. 🟢 **TTS 进程常驻** —— 白捡 11 秒
2. 🟢 **实测 SenseVoice 在板上的真实 RTF**（官方 A55@1.8GHz 4线程 RTF=0.175，A73 只会更好）—— 5 分钟
3. 🔴 **试 Piper 中文** —— Synaptics 官方示例路线
4. 🟢 **把"说一句回一句"闭环跑通**（VAD+SenseVoice → 回显 → TTS）

### 第二步
5. C920 到货 → **摄像头感知唤醒**（NPU 真加速）+ UVC 测试
6. 唤醒词：openWakeWord 或中文词，二选一实测
7. 自建 xiaozhi-server（先在 PC 上跑通，再评估上板）

### 第三步
8. 双模切换（本地兜底 + 联网增强）
9. 声音克隆（PC 克隆 → 导出 → 板上推理）

---

## 八、必须实测才能确定的点 🔴

- Piper 中文在 A73 上的 RTF（**无任何公开数据**）
- SenseVoice 在这块板子上的真实 RTF
- Gemma-3-270M 在 A73 上的 tok/s（**无实测数据**；RPi4 同样无 dotprod，1–1.5B 模型 <5 tok/s）
- Yocto 上能否装起 Python 栈（**最大落地不确定项** —— 板上无 pip，glibc 是否匹配 manylinux_2_17 未知）
- 唤醒词失败的真因（口音 vs 信噪比，需设计能分离两者的实验）

---

## 九、SyNAP 探针（如果要亲自验证 NPU，约 1 天）

```bash
docker pull ghcr.io/synaptics-synap/toolkit:3.1.0   # ⚠️ 3.1.1 没有镜像
# Python 必须锁 3.10 或 3.12（PyArmor 只有这两个 runtime）
synap convert --model sensevoice.onnx --target SL1680 --meta meta.yaml --out-dir out/ --profiling
# 看有多少子图掉到 CPU
```

**两个真陷阱** 🔵：
- `pip install synap` **会装到无关的第三方包**（PyPI 上的 `synap` 是别人的 "Cognitive memory architecture for LLM agents"）
- `toolkit-prebuilts` 里 acuitylib 是 **PyArmor 混淆的闭源代码**，底层是 VeriSilicon Acuity Toolkit 6.21.2。**转换失败时你看不到也改不了转换器内部。**

---

## 附录：本次调查的方法论教训

在麦克风排查中，我连续提出并**推翻了六个假设**（低通滤波、削波失真、重采样混叠、端点检测截断、声道抵消、187.5Hz 数字伪影）。

**根因不是技术，是方法**：我一直在"找一个能解释现象的合理原因"，却从未验证最基本的前提 —— **那段音频里到底是什么内容**。

最后是靠一段**内容已知**的录音（我指定用户说 "LIGHT UP + astra×3"）+ 一个**更强的独立模型**（PC 端 SenseVoice）拿到地面真相：

```
要求说的:   「LIGHT UP ...  astra    astra    astra 」
实际听到:   「Not  up  ... after ,  after ,  not after」
```

**音频一直是好的。ASR 返回空是正确行为 —— "astra" 是生造词，不在任何语言模型词表里。**

其中 187.5Hz 那个假设尤其值得记取：我用 1024 点 FFT（分辨率 15.625Hz）测出"187.5Hz"，发现它 = 48000÷256，于是构建了一套"块边界伪影"理论。**实际上 187.5 只是第 12 个 bin —— 我把量化误差当成了物理证据。** 后来用 16384 点 FFT（0.977Hz）一测，峰值是 181.64/187.50/191.41 的簇，**而官方音频呈现完全相同的簇**。

> **教训：先拿地面真相，再建理论。凡是"只有这一个来源能证明"的结论，都要用独立方法交叉验证。**
>
> 本报告中每个 🟢 标记的数字，都可以在板子上复现。
