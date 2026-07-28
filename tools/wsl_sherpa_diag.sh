#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
S=$W/git
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)

echo "════ 1. CMake Error 完整上下文(前 3 个) ════"
grep -n -A6 "CMake Error" "$L" 2>/dev/null | head -n 30 | sed 's/^/  /'

echo
echo "════ 2. 下载到哪去了 / 成功了吗 ════"
echo "  build/_deps 下的内容:"
ls $W/build/_deps 2>/dev/null | sed 's/^/    /' || echo "    (没有 _deps)"
echo "  下载的压缩包(*-subbuild 里):"
find $W/build/_deps -maxdepth 3 -name "*.tar.gz" -o -maxdepth 3 -name "*.zip" 2>/dev/null | head -n 8 | sed 's|.*/|    |'

echo
echo "════ 3. WSL 里能不能访问 GitHub ════"
for u in https://github.com https://raw.githubusercontent.com; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 8 "$u" 2>/dev/null)
  echo "  $u -> HTTP $code"
done
echo "  实测下一个真包(kaldi-native-fbank v1.22.3):"
curl -sIL -m 15 -o /dev/null -w "    HTTP %{http_code}  大小 %{size_download}  耗时 %{time_total}s\n" \
  "https://github.com/csukuangfj/kaldi-native-fbank/archive/refs/tags/v1.22.3.tar.gz" 2>/dev/null

echo
echo "════ 4. sherpa 的 cmake 模块支不支持本地文件覆盖 ════"
echo "  kaldi-native-fbank.cmake 里的取源逻辑:"
sed -n '1,40p' $S/cmake/kaldi-native-fbank.cmake 2>/dev/null | grep -nE "set\(|if\(EXISTS|FetchContent_Declare|URL|file://" | head -n 20 | sed 's/^/    /'

echo
echo "════ 5. 一共要下多少个第三方包 ════"
ls $S/cmake/*.cmake 2>/dev/null | sed 's|.*/|  |'
echo "  各自的 URL 和版本:"
grep -hoE 'https://[^"$)]*\.(tar\.gz|zip)' $S/cmake/*.cmake 2>/dev/null | sort -u | sed 's/^/    /'
