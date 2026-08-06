#!/bin/bash
set -e
W=/tmp/tcmpatch
rm -rf $W; mkdir -p $W
T=/home/astra/sdk/meta-tcm2-touch/recipes-kernel/linux-drivers/synaptics-tcm2/files/synaptics_tcm2_touchcomm_tddi_v1.8.0.tar.gz
tar -xzf "$T" -C $W
SRC=$W/synaptics_tcm2_touchcomm_tddi_v1.8.0/source/synaptics_tcm2
cp -a $SRC $W/orig
cd $SRC

python3 - <<'PYEOF'
import io
# --- 1) 开 ENABLE_HELPER ---
p = "syna_tcm2.h"
s = io.open(p, encoding="utf-8", errors="surrogateescape").read()
old = "/* #define ENABLE_HELPER */"
assert s.count(old) == 1, "ENABLE_HELPER 宏未找到"
s = s.replace(old, "#define ENABLE_HELPER")
io.open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)

# --- 2) ISR 里不再同步重配固件 ---
p = "syna_tcm2.c"
s = io.open(p, encoding="utf-8", errors="surrogateescape").read()
old = """		if (app_status != APP_STATUS_OK)
			LOGI("Bad app status: 0x%x\\n", app_status);
		tcm->dev_set_up_app_fw(tcm);
	}"""
new = """		if (app_status != APP_STATUS_OK)
			LOGI("Bad app status: 0x%x\\n", app_status);
		/* This callback runs in the interrupt thread context.
		 * dev_set_up_app_fw() writes over I2C and takes a mutex, so calling
		 * it synchronously here wedges the IRQ thread forever (observed:
		 * "INFO: task irq/49-synaptic blocked for more than 983 seconds"),
		 * leaving touch dead and even rmmod stuck. When the background
		 * helper is available, let the workqueue below do it instead.
		 */
#if defined(ENABLE_HELPER)
		if (!tcm->helper.workqueue)
			tcm->dev_set_up_app_fw(tcm);
#else
		tcm->dev_set_up_app_fw(tcm);
#endif
	}"""
assert s.count(old) == 1, "ISR 重配代码块未找到"
s = s.replace(old, new)
io.open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("  源码改动完成")
PYEOF

cd $W
diff -u orig/syna_tcm2.h synaptics_tcm2_touchcomm_tddi_v1.8.0/source/synaptics_tcm2/syna_tcm2.h \
  | sed -e '1s|.*|--- a/syna_tcm2.h|' -e '2s|.*|+++ b/syna_tcm2.h|' > /tmp/p1.diff || true
diff -u orig/syna_tcm2.c synaptics_tcm2_touchcomm_tddi_v1.8.0/source/synaptics_tcm2/syna_tcm2.c \
  | sed -e '1s|.*|--- a/syna_tcm2.c|' -e '2s|.*|+++ b/syna_tcm2.c|' > /tmp/p2.diff || true

OUT=/home/astra/sdk/meta-tcm2-touch/recipes-kernel/linux-drivers/synaptics-tcm2/files/0001-enable-helper-and-fix-isr-deadlock.patch
{
cat <<'HDR'
From: SL1680 Astra project
Date: 2026-07-28
Subject: [PATCH] TDDI spontaneous-reset self-heal: enable ENABLE_HELPER and
 move the post-reset re-config out of the IRQ thread

TDDI parts spontaneously reset at runtime and lose their working config.
On REPORT_IDENTIFY the driver re-configured the firmware *from the interrupt
thread*: dev_set_up_app_fw() writes over I2C and takes a mutex, so the IRQ
thread blocked forever. Measured on SL1680 + TM10.5-TD7800:

  INFO: task irq/49-synaptic:500 blocked for more than 983 seconds.
  syna_dev_isr -> syna_tcm_get_event_data -> syna_tcm_v1_read_message
  -> syna_dev_process_unexpected_reset -> syna_dev_set_up_app_fw
  -> syna_tcm_get_app_info -> syna_tcm_v1_write_message -> mutex_lock

Touch went completely dead and even unbind/rmmod hung; only a reboot cleared
it. A watchdog retried every 122.9 s, wedging one more thread each time.

Two changes:
1) Enable ENABLE_HELPER - the driver's own background workqueue, designed for
   exactly this "reconfigure after reset" job. The sister project (Case44,
   RK3568 with the same TD7800) verified touch self-heals once it is on.
2) With the helper present, do not call dev_set_up_app_fw() inline in the ISR;
   only queue the work. Upstream left that call *outside* the ENABLE_HELPER
   guard, so merely enabling the helper still deadlocked. Behaviour without
   the helper is unchanged.

HDR
cat /tmp/p1.diff
cat /tmp/p2.diff
} > "$OUT"

echo "  补丁: $OUT"
wc -l "$OUT"
echo "════ 补丁内容(diff 部分) ════"
grep -A6 "^--- a/" "$OUT" | head -n 40
