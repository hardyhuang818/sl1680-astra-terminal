SUMMARY = "Astra 语音终端 —— 一台开箱能用的 SL1680 需要的全部软件"
DESCRIPTION = "把 SL1680 变成语音终端所需的包集合：\
板上 ASR/TTS + 云端大脑 + DL7400 多屏对话界面 + 视觉唤醒。\
装了这个包组，烧完镜像开机就能跑（只差模型和 API key，见下）。"
LICENSE = "MIT"

inherit packagegroup

COMPATIBLE_MACHINE = "(dolphin)"

# 各自的运行时依赖(sherpa-onnx / dlsdk / synap / 字体 / python3 / gstreamer …)
# 都写在 astra-voice 和 dl-face 自己的 RDEPENDS 里，这里不重复列，
# 免得两处不同步。这个包组只回答一个问题：**这台机器是干什么的**。
RDEPENDS:${PN} = "\
    astra-voice \
    dl-face \
"

# ═══════════════════════════════════════════════════════════════
# ⚠️ 装完这个包组还差两样东西，镜像里给不了：
#
#   1. 模型（约 2GB）—— /home/voice/{sv,matcha,tts,llm}
#      不进 recipe 的原因和补齐办法见
#      meta-dlsdk/recipes-ai/astra-voice/files/README_models.md
#      校验清单见同目录 MODEL_MANIFEST.txt
#
#   2. API key —— 复制 /etc/astra/llm.conf.sample 成 llm.conf 填自己的 key
#      chmod 600。缺 DEEPSEEK_API_KEY 会回落到板上的本地小模型；
#      缺 ZHIPU_API_KEY 只是问天气/股价时会老实说查不到。
#
# 没有模型时 astra-voice 起不来（会在日志里说找不到模型文件），
# 但 dl-face 和视觉唤醒不受影响。
# ═══════════════════════════════════════════════════════════════
