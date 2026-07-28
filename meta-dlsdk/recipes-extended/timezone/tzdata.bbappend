# 板子默认时区 = 上海（rootfs 组装时由 tzdata 包写 /etc/localtime 与 /etc/timezone）
# 之前是烧完手工拷 zoneinfo（rootfs 三件套之一），v2.8 起进镜像。
DEFAULT_TIMEZONE = "Asia/Shanghai"
