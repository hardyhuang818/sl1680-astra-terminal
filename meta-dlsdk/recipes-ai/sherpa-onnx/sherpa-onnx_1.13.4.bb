SUMMARY = "sherpa-onnx — 端侧语音识别/合成/VAD (中英双语)"
DESCRIPTION = "next-gen Kaldi 的 onnxruntime 推理框架。\
★为什么选它★ 纯 C++、不依赖 pip/python —— 正好适配 SL1680:\
板子上【没有 pip、没有 gcc/cmake】，所有东西必须在 WSL 交叉编译后传上去。\
支持:流式中英双语 ASR(zipformer-bilingual-zh-en)、TTS(VITS/matcha)、VAD(silero)。"
HOMEPAGE = "https://github.com/k2-fsa/sherpa-onnx"

# ⚠️⚠️ 授权：sherpa-onnx 自身是 Apache-2.0，但开着 TTS 就会把 **espeak-ng(GPLv3)**
#        编进 libsherpa-onnx-core.so —— GPLv3 会穿透整条链路，
#        任何链接它的程序(astra_voice)都受影响。产品化前必须解决：
#        要么换掉不依赖 espeak-ng 的 TTS 前端，要么接受 GPLv3 开源义务。
#        LIC_FILES_CHKSUM 只覆盖 sherpa 自己的 LICENSE，第三方各自的许可见其源码包。
LICENSE = "Apache-2.0 & GPL-3.0-or-later & MIT & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=3b83ef96387f14655fc854ddc3c6bd57"

# 固定到 v1.13.4 tag(可复现)，不用 AUTOREV
SRC_URI = "git://github.com/k2-fsa/sherpa-onnx.git;protocol=https;branch=master"
SRCREV = "142807252687d81b40d6315f23470a1512a00de3"

# ═══════════════════════════════════════════════════════════════════════
# 第三方依赖：为什么要在这里一个个列出来
# ═══════════════════════════════════════════════════════════════════════
# sherpa 的 CMake 用 FetchContent 在 configure 期从 GitHub 拉 8 个第三方源码包。
# 但 **Yocto 的 cmake.bbclass 硬性传了 -DFETCHCONTENT_FULLY_DISCONNECTED=ON**
# (poky/meta/classes-recipe/cmake.bbclass:186)，为的是构建可复现、不偷偷联网。
#
# 结果：FetchContent 一声不吭地什么都不做，随后 add_subdirectory 对着不存在的
# _deps/xxx-src 目录报错，configure 直接失败。日志里只有 sherpa 自己打印的
# "-- Downloading xxx"(那只是 message(STATUS))，**没有任何 curl/HTTP/超时记录** ——
# 这正是"根本没尝试联网"的特征，别误判成网络不通。
#
# ⚠️ 给 do_configure 加 [network]="1" **解决不了** 这个问题，那是两码事。
#
# 正确做法：让 Yocto 的 fetcher 在 do_fetch 阶段把这些包拉下来(带 sha256 校验、
# 支持 PREMIRRORS、可离线复现)，再放到 sherpa 的 CMake 会去找的位置。
# sherpa 每个 cmake 模块都有 possible_file_locations 列表，其中包含
# ${CMAKE_SOURCE_DIR}/<期望文件名>，找到就直接用 file:// 而不联网。
# 所以 do_configure:prepend 把它们按期望的文件名拷进 ${S} 即可。
#
# ★ 加新依赖时：文件名必须和对应 cmake 模块里写死的一模一样，差一个字符就失效。
SRC_URI += "\
    https://github.com/csukuangfj/kaldi-native-fbank/archive/refs/tags/v1.22.3.tar.gz;name=knf;downloadfilename=kaldi-native-fbank-1.22.3.tar.gz;unpack=0 \
    https://github.com/k2-fsa/kaldi-decoder/archive/refs/tags/v0.3.0.tar.gz;name=kd;downloadfilename=kaldi-decoder-0.3.0.tar.gz;unpack=0 \
    https://github.com/pkufool/simple-sentencepiece/archive/refs/tags/v0.7.tar.gz;name=ssp;downloadfilename=simple-sentencepiece-0.7.tar.gz;unpack=0 \
    https://github.com/nlohmann/json/archive/refs/tags/v3.12.0.tar.gz;name=json;downloadfilename=json-3.12.0.tar.gz;unpack=0 \
    https://github.com/likle/cargs/archive/refs/tags/v1.0.3.tar.gz;name=cargs;downloadfilename=cargs-1.0.3.tar.gz;unpack=0 \
    https://github.com/csukuangfj/espeak-ng/archive/ed530aa113046142eb5115cf2fc9157854d0ffe1.zip;name=espeak;downloadfilename=espeak-ng-ed530aa113046142eb5115cf2fc9157854d0ffe1.zip;unpack=0 \
    https://github.com/csukuangfj/piper-phonemize/archive/f3ff95afc03640bc1399e113e83361192a2fafb4.zip;name=piper;downloadfilename=piper-phonemize-f3ff95afc03640bc1399e113e83361192a2fafb4.zip;unpack=0 \
    https://github.com/csukuangfj/onnxruntime-libs/releases/download/v1.27.0/onnxruntime-linux-aarch64-glibc2_17-Release-1.27.0.zip;name=ort;downloadfilename=onnxruntime-linux-aarch64-glibc2_17-Release-1.27.0.zip;unpack=0 \
    https://github.com/mborgerding/kissfft/archive/febd4caeed32e33ad8b2e0bb5ea77542c40f18ec.zip;name=kissfft;downloadfilename=kissfft-febd4caeed32e33ad8b2e0bb5ea77542c40f18ec.zip;unpack=0 \
    https://github.com/k2-fsa/kaldifst/archive/refs/tags/v1.8.0.tar.gz;name=kaldifst;downloadfilename=kaldifst-1.8.0.tar.gz;unpack=0 \
    https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz;name=eigen34;downloadfilename=eigen-3.4.0.tar.gz;unpack=0 \
    https://gitlab.com/libeigen/eigen/-/archive/5.0.1/eigen-5.0.1.tar.gz;name=eigen50;downloadfilename=eigen-5.0.1.tar.gz;unpack=0 \
    https://github.com/csukuangfj/openfst/archive/refs/tags/v1.8.5-2026-04-11.tar.gz;name=ofst11;downloadfilename=openfst-1.8.5-2026-04-11.tar.gz;unpack=0 \
    https://github.com/csukuangfj/openfst/archive/refs/tags/v1.8.5-2026-04-10.tar.gz;name=ofst10;downloadfilename=openfst-1.8.5-2026-04-10.tar.gz;unpack=0 \
"

SRC_URI[knf.sha256sum]   = "9176cc66fc7ce1edf85cf355b06e320c57db6297df74277f575183468893cf61"
SRC_URI[kd.sha256sum]    = "b9f34cfb4fd3b1344100eead79ef4d37aa15962274b9e3056de345021f76a1b0"
SRC_URI[ssp.sha256sum]   = "1748a822060a35baa9f6609f84efc8eb54dc0e74b9ece3d82367b7119fdc75af"
SRC_URI[json.sha256sum]  = "4b92eb0c06d10683f7447ce9406cb97cd4b453be18d7279320f7b2f025c10187"
SRC_URI[cargs.sha256sum] = "ddba25bd35e9c6c75bc706c126001b8ce8e084d40ef37050e6aa6963e836eb8b"
SRC_URI[espeak.sha256sum]= "e4e262cbe34f7fe21f91f1ba3397f2728e1f30eafbae7853f2b753a9ed13f0dd"
SRC_URI[piper.sha256sum] = "d9cca4e2bdc7d6dd8dffb96a4668283dbd3f77a9c194a3e530c1e8eba9406a5d"
SRC_URI[ort.sha256sum]   = "06e6dbe506fae40d8d735cf22378f7009bfe662cfffca76cb1d8ecea18a63826"
# ── 嵌套依赖（子项目自己还要下的东西）──
# CMake 的 CMAKE_SOURCE_DIR 始终指向【顶层】源码目录(=${S})，所以子项目的
# possible_file_locations 也能命中我们放在 ${S} 的包 —— 嵌套层用同一招即可。
#   kaldi-native-fbank -> kissfft
#   kaldi-decoder      -> kaldifst, eigen
#   kaldifst           -> openfst
# ⚠️ eigen 同样有两个版本：sherpa 要 5.0.1，kaldi-decoder 要 3.4.0，两个都备着。
# (pybind11 / googletest 只在 python/tests 开启时才要，我们都关了，不用带)
#
# ⚠️ openfst 有【两个日期不同的版本】：sherpa 自己要 2026-04-11，kaldifst 要 2026-04-10。
#    FetchContent 是首个声明生效、后面的被忽略，但我们无法预知谁先声明，
#    所以两个都备着 —— 多下一个包代价很小，少一个就会卡在"Could not resolve host"。
SRC_URI[kissfft.sha256sum] = "497103e664168ebe39580b757adbe616f6cf85a16572af581ca7bc42d0ab13fd"
SRC_URI[kaldifst.sha256sum]= "3f247b7e5a2409071202f5e2bc6200060f66728c0a3443c03923ad2723e040b3"
SRC_URI[eigen34.sha256sum] = "8586084f71f9bde545ee7fa6d00288b264a2b7ac3607b974e54d13e7162c1c72"
SRC_URI[eigen50.sha256sum] = "e9c326dc8c05cd1e044c71f30f1b2e34a6161a3b6ecf445d56b53ff1669e3dec"
SRC_URI[ofst11.sha256sum]  = "57fbc4b950ae81b1a0e1e298af15652da968a6723a592b7874e9b4027a80a5b4"
SRC_URI[ofst10.sha256sum]  = "c3549940384cbe4fa9f18c2bcfb1bfbd0a80492fd1b0bfa27433cee395a6a199"

# 拷进 ${S} 时用的文件名，必须与各 cmake 模块里的期望名逐字一致
SHERPA_CMAKE_DEPS = "\
    kaldi-native-fbank-1.22.3.tar.gz \
    kaldi-decoder-0.3.0.tar.gz \
    simple-sentencepiece-0.7.tar.gz \
    json-3.12.0.tar.gz \
    cargs-1.0.3.tar.gz \
    espeak-ng-ed530aa113046142eb5115cf2fc9157854d0ffe1.zip \
    piper-phonemize-f3ff95afc03640bc1399e113e83361192a2fafb4.zip \
    onnxruntime-linux-aarch64-glibc2_17-Release-1.27.0.zip \
    kissfft-febd4caeed32e33ad8b2e0bb5ea77542c40f18ec.zip \
    kaldifst-1.8.0.tar.gz \
    eigen-3.4.0.tar.gz \
    eigen-5.0.1.tar.gz \
    openfst-1.8.5-2026-04-11.tar.gz \
    openfst-1.8.5-2026-04-10.tar.gz \
"

S = "${WORKDIR}/git"

# ★ 去掉 -Werror=format-security（只去 -Werror，警告本身保留）
#   Yocto 默认 SECURITY_STRINGFORMAT="-Wformat -Wformat-security -Werror=format-security"。
#   espeak-ng 的 CMake 会重设自己的 C 标志，把 -Wformat 弄丢，只剩 -Wformat-security，
#   gcc 于是报 "'-Wformat-security' ignored without '-Wformat'"，再被 -Werror 变成致命错误：
#     FAILED: _deps/espeak_ng-build/src/libespeak-ng/.../compiledata.c.o
#   实测 C++ 部分全部正常(编到 602 个目标里的第 62 个才炸)，只有 espeak-ng 的 C 文件中招。
#   这里保留两个 -W 警告、只摘掉 -Werror，比整组关掉加固(SECURITY_STRINGFORMAT="")影响面小。
SECURITY_STRINGFORMAT = "-Wformat -Wformat-security"

inherit cmake pkgconfig

DEPENDS = "alsa-lib"
RDEPENDS:${PN} = "alsa-lib"

COMPATIBLE_MACHINE = "(dolphin)"

# 关键配置:
#  * 关 python/测试/示例 —— 只要 C++ 库和命令行工具
#  * 开 ALSA —— 板子有 arecord/aplay，语音要实时采集
#  * 关 portaudio —— 用 ALSA 就够，少一个依赖
#  * 关 speaker diarization —— 用不上，还能少拉 hclust-cpp 一个依赖
#  * TTS 必须开 —— matcha TTS 走的就是它(代价是引入 espeak-ng GPLv3，见顶部授权说明)
#
# ★ 关于 -DFETCHCONTENT_FULLY_DISCONNECTED=OFF
#   cmake.bbclass 的 OECMAKE_ARGS 里硬性传了 ...=ON。它的本意是"不许在 configure 期偷偷联网"。
#   但实测这个开关**连本地文件的解压也一并禁掉了** —— 上面把包放进 ${S} 之后，
#   日志里已经能看到 `-- Downloading cargs /…/git/cargs-1.0.3.tar.gz`(本地路径，没连网)，
#   可 FetchContent 依然什么都不做，随后 add_subdirectory 对着空目录报错。
#   既然所有 URL 都已经指向本地文件、网络访问已经从根上消除，这里就该把它关掉。
#   OECMAKE_ARGS 排在 EXTRA_OECMAKE 前面，CMake 取最后一个同名 -D，所以这里能覆盖。
#   ⚠️ 前提是上面 8 个包必须全部命中本地文件 —— 万一哪个没命中，它就会真去联网，
#      构建就不可复现了。改依赖时请核对日志里的 "Found local downloaded"。
EXTRA_OECMAKE = " \
    -DFETCHCONTENT_FULLY_DISCONNECTED=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
    -DSHERPA_ONNX_ENABLE_TESTS=OFF \
    -DSHERPA_ONNX_ENABLE_CHECK=OFF \
    -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
    -DSHERPA_ONNX_ENABLE_JNI=OFF \
    -DSHERPA_ONNX_ENABLE_C_API=ON \
    -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
    -DSHERPA_ONNX_ENABLE_GPU=OFF \
    -DSHERPA_ONNX_ENABLE_ALSA=ON \
    -DSHERPA_ONNX_ENABLE_BINARY=ON \
    -DSHERPA_ONNX_ENABLE_TTS=ON \
    -DSHERPA_ONNX_ENABLE_SPEAKER_DIARIZATION=OFF \
"

do_configure:prepend() {
    # 把 do_fetch 拉好的第三方包放到 CMAKE_SOURCE_DIR，让 sherpa 的
    # possible_file_locations 命中，从而完全不需要联网。
    for f in ${SHERPA_CMAKE_DEPS}; do
        if [ -f "${WORKDIR}/$f" ]; then
            cp -f "${WORKDIR}/$f" "${S}/$f"
        else
            bbfatal "第三方包缺失: ${WORKDIR}/$f —— 检查 SRC_URI 的 downloadfilename 是否与 SHERPA_CMAKE_DEPS 一致"
        fi
    done
}

do_install:append() {
    # 两个第三方 CMake 把文件装错了地方，Yocto 的 QA 会报
    # "installed but not shipped in any package" 并直接失败。
    # 挪到标准位置比加 FILES 覆盖干净 —— 挪好之后 ${PN}-dev 会自动收走。
    #   sherpa-onnx.pc : 装到了 ${prefix} 根下，应在 ${libdir}/pkgconfig/
    #   cargs.h        : cargs 把头文件装进了 ${libdir}
    if [ -f ${D}${prefix}/sherpa-onnx.pc ]; then
        install -d ${D}${libdir}/pkgconfig
        mv ${D}${prefix}/sherpa-onnx.pc ${D}${libdir}/pkgconfig/sherpa-onnx.pc
    fi
    if [ -f ${D}${libdir}/cargs.h ]; then
        install -d ${D}${includedir}
        mv ${D}${libdir}/cargs.h ${D}${includedir}/cargs.h
    fi
}

FILES:${PN} += "${bindir}/sherpa-onnx*"
INSANE_SKIP:${PN} += "already-stripped ldflags"

# ★ libonnxruntime.so 是 sherpa 自带的【预编译】二进制(33.9MB，随源码包一起下来)，
#   和 libsherpa-onnx-c-api.so 装在同一个包、同一个目录，
#   而且 c-api 的 RUNPATH 就是 $ORIGIN —— 运行时能找到，依赖是真的满足的。
#   但 Yocto 的 file-rdeps QA 要的是【带符号版本】的 provider
#   (libonnxruntime.so(VERS_1.27.0)(64bit))，外来预编译二进制不会被登记成提供者，
#   于是报 "no providers found in RDEPENDS"。这里显式声明它。
#   ⚠️ 升级 onnxruntime 版本时这一行要跟着改，否则 QA 会再次报错(这是好事，会提醒你)。
RPROVIDES:${PN} += "libonnxruntime.so(VERS_1.27.0)(64bit)"

# ⚠️ sherpa-onnx 的 CMake 从不设 SOVERSION，产出的是无版本号的
#    libsherpa-onnx-c-api.so / libsherpa-onnx-core.so。
#    Yocto 默认把无版本号的 .so 当成开发用软链，全部丢进 ${PN}-dev ——
#    结果运行时镜像里根本没有这个库，链接它的 astra_voice 会以
#    "cannot open shared object file" 起不来，而且构建期一切正常，
#    只有烧进板子才会暴露。
#    下面两行把无版本号 .so 声明成运行时库，dev 包不再抢。
SOLIBS = ".so"
FILES_SOLIBSDEV = ""
