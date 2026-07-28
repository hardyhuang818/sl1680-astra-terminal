#!/bin/bash
# 同步 sherpa recipe 并真跑 do_configure
cp "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb" \
   /home/astra/sdk/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo "════ 1. 解析检查 ════"
bitbake -e sherpa-onnx > /tmp/e.txt 2>/tmp/e.err
if [ $? -ne 0 ]; then echo "  ❌ 解析失败"; grep -E "ERROR|Exception" /tmp/e.err | head -n 8; exit 1; fi
echo "  ✅ 解析通过"
echo "  SRC_URI 里的 http 条目数: $(grep '^SRC_URI=' /tmp/e.txt | tr ' ' '\n' | grep -c '^https://')"
echo "  LICENSE: $(grep '^LICENSE=' /tmp/e.txt | cut -d'"' -f2)"
grep -E '^SHERPA_CMAKE_DEPS=' /tmp/e.txt | tr ' ' '\n' | grep -c "tar.gz\|zip" | sed 's/^/  SHERPA_CMAKE_DEPS 条目数: /'

echo
echo "════ 2. 清掉旧的失败状态，重跑 fetch + configure ════"
bitbake -c cleansstate sherpa-onnx > /tmp/c.txt 2>&1 && echo "  cleansstate OK" || { echo "  cleansstate 失败"; tail -n 5 /tmp/c.txt; }

echo
echo "════ 3. do_fetch(下 8 个第三方包，第一次会比较慢) ════"
bitbake -c fetch sherpa-onnx > /tmp/f.txt 2>&1
if [ $? -ne 0 ]; then
  echo "  ❌ fetch 失败"; grep -E "ERROR|checksum|Fetcher failure|404" /tmp/f.txt | head -n 12
  exit 1
fi
echo "  ✅ fetch 成功"
ls -la $(grep -m1 '^DL_DIR=' /tmp/e.txt | cut -d'"' -f2)/ 2>/dev/null | grep -E "kaldi|json|cargs|espeak|piper|onnxruntime-linux-aarch64|simple-sent" | awk '{printf "    %10s  %s\n",$5,$9}'

echo
echo "════ 4. do_configure(真正的考验) ════"
bitbake -c configure sherpa-onnx > /tmp/cf.txt 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  echo "  ✅✅ configure 通过了"
  W=build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
  L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)
  echo "  命中本地包的证据:"
  grep -E "Found local downloaded" "$L" | sed 's/^/    /'
  echo "  _deps 里解出来的源码:"
  ls $W/build/_deps 2>/dev/null | grep -- "-src$" | sed 's/^/    /'
else
  echo "  ❌ configure 仍失败 (rc=$RC)"
  grep -E "ERROR" /tmp/cf.txt | head -n 5
  W=build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
  L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)
  echo "  --- CMake 错误 ---"
  grep -A4 "CMake Error" "$L" 2>/dev/null | head -n 20 | sed 's/^/    /'
  echo "  --- 命中了哪些本地包 ---"
  grep -E "Found local downloaded" "$L" 2>/dev/null | sed 's/^/    /'
fi
