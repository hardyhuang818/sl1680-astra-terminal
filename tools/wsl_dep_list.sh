#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)
echo "════ 本配置实际要下载的全部包(权威清单) ════"
grep -E "^-- Downloading" "$L" | sed 's/^-- Downloading /  /' | sed 's| from | <- |'
echo
echo "  共 $(grep -cE '^-- Downloading' "$L") 个"
echo
echo "════ 全部 CMake Error 涉及的模块 ════"
grep -oE "cmake/[a-z0-9-]*\.cmake" "$L" | sort -u | sed 's/^/  /'
echo
echo "════ 关键开关的最终取值 ════"
grep -E "^-- SHERPA_ONNX_ENABLE_(TTS|SPEAKER_DIARIZATION|BINARY|C_API|PORTAUDIO|WEBSOCKET|TESTS|PYTHON)" "$L" | sed 's/^/  /'
grep -E "^-- BUILD_SHARED_LIBS" "$L" | sed 's/^/  /'
