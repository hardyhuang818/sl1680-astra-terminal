#!/bin/bash
B=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-build-artifacts
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
CFG=$(ls "$B/.config" 2>/dev/null || find /home/astra/sdk/build-sl1680/tmp/work -name ".config" -path "*linux-syna*" 2>/dev/null | head -1)
echo "=== 内核 .config: $CFG ==="
[ -f "$CFG" ] || { echo "  找不到 .config"; exit 1; }

echo "--- PWM 子系统 ---"
grep -E "^CONFIG_PWM[= ]|^CONFIG_PWM_SYSFS|^# CONFIG_PWM " "$CFG"
echo "--- PCA9685 ---"
grep -iE "PCA9685" "$CFG" || echo "  (没有任何 PCA9685 条目 -> 驱动未编，也未设为 m)"
echo "--- I2C 用户态接口 ---"
grep -E "^CONFIG_I2C_CHARDEV|^CONFIG_I2C=" "$CFG"
echo "--- 相关可选项 ---"
grep -E "^CONFIG_SERVO|^CONFIG_INPUT_PWM|^CONFIG_LEDS_PCA" "$CFG" 2>/dev/null

echo
echo "=== 内核源码里有没有这个驱动 ==="
ls -la "$K/drivers/pwm/pwm-pca9685.c" 2>/dev/null && echo "  ✓ 源码在（可直接开 CONFIG_PWM_PCA9685=m）" || echo "  ✗ 源码不在"
grep -n "PWM_PCA9685" "$K/drivers/pwm/Kconfig" 2>/dev/null | head -3

echo
echo "=== 板子当前 i2c 控制器在 dts 里的样子（找空闲总线） ==="
D=$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
grep -n -A6 "^&i2c[0-9]" "$D" | head -50
