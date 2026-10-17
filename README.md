# Banana Pi BPi-R4 OpenWrt/ImmortalWrt 固件构建仓库

本项目是专为 **香蕉派 Banana Pi BPi-R4 (MediaTek MT7988A Filogic 880)** 定制的高性能**纯有线主路由** OpenWrt / ImmortalWrt 固件自动化构建项目。

---

## 🌟 核心特性与定制优化

1. **纯有线万兆主路由定制**：
   - 彻底屏蔽所有 Wi-Fi 驱动（mt76 / mt7996 / hostapd / wpad），释放射频内核资源，专注极致的有线转发与低延迟。
2. **硬件流表 PPE 极致加速**：
   - 注入内核优化补丁，将 MT7988 的 PPE 硬件流表项由默认 16,384 扩容至 **32,768** 项，轻松应对高并发万兆连接。
3. **M.2 NVMe SSD 与大容量存储开箱即用**：
   - 预置 `kmod-nvme`、`kmod-usb-storage`、`kmod-fs-ext4`、`btrfs`、`f2fs` 等存储与文件系统驱动，完美发挥 M.2 Key-M 接口能力。
4. **内核调试噪音过滤**：
   - 屏蔽 MT7988 平台在 dmesg 中的 `devfreq cci warning` 刷屏，保持内核运行日志清爽。
5. **精选服务套件**：
   - **DNS 分流与过滤**：MosDNS v5（全中文管理套件）
   - **穿透与重定向**：Lucky 官方核心、Socat、UPnP
   - **异地组网**：EasyTier 去中心化 Mesh 组网、ZeroTier
   - **存储与共享**：Samba4、Diskman 磁盘管理
   - **测速与监控**：NetSpeedTest (iPerf3)、Prometheus Node Exporter
   - **透明代理**：OpenClash
6. **高效 CI/CD 构建**：
   - 引入 **Ccache** 与 **dl 依赖缓存**，后续构建耗时从 3 小时缩短至 30 分钟以内；
   - 自动生成 SHA256 校验清单，并自动发布固件至 GitHub Releases。

---

## 🚀 编译与构建说明

### 手动触发构建 (workflow_dispatch)

1. 点击仓库上方的 **Actions** 标签；
2. 在左侧选择 **Build Banana Pi BPi-R4 Firmware** 工作流；
3. 点击右侧的 **Run workflow**：
   - **选择 0x5826 源码分支**：默认推荐 `openwrt-25.12`（活跃维护分支，内核 6.12），亦可按需选择 `master`；
   - **是否发布到 GitHub Releases**：勾选后编译完成将自动创建 Tag 并发布 Releases 固件下载。

---

## 📁 固件刷机说明

构建产物（Releases 或 Artifacts）包含以下主要文件：

| 文件名格式 | 说明与用途 |
| :--- | :--- |
| `*sdcard.img.gz` | **SD 卡全量启动镜像**（烧录至 MicroSD 卡启动使用） |
| `*sysupgrade.itb` | **系统在线/后台升级包**（在现有 OpenWrt 后台选择升级） |
| `*emmc-preloader.bin` / `*emmc-bl31-uboot.fip` | eMMC 启动引导固件（U-Boot 阶段） |
| `SHA256SUMS` | 固件文件 SHA256 校验和清单，刷机前请务必校验完整性 |

---

## 📜 鸣谢与上游开源项目

- [0x5826/immortalwrt-mtk](https://github.com/0x5826/immortalwrt-mtk)
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns)
- [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky)
- [EasyTier](https://github.com/EasyTier/luci-app-easytier)