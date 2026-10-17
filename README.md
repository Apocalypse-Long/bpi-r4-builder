<div align="center">

# 🚀 Banana Pi BPi-R4 专属 ImmortalWrt 纯有线旗舰固件构建

[![Build Firmware](https://github.com/Apocalypse-Long/bpi-r4-builder/actions/workflows/build-firmware.yml/badge.svg)](https://github.com/Apocalypse-Long/bpi-r4-builder/actions/workflows/build-firmware.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Apocalypse-Long/bpi-r4-builder?color=blue&logo=github)](https://github.com/Apocalypse-Long/bpi-r4-builder/releases)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.12%20(Kernel%206.12)-blue.svg?logo=openwrt)](https://github.com/0x5826/immortalwrt-mtk)
[![License](https://img.shields.io/github/license/Apocalypse-Long/bpi-r4-builder)](LICENSE)

**专为香蕉派 Banana Pi BPi-R4 (MediaTek MT7988A Filogic 880) 定制的万兆纯有线主路由固件**  
*双万兆 SFP+ | 硬件流表 PPE 32K 扩容 | 开箱即用 M.2 NVMe SSD 支持 | 现代 shadcn/ui 侧边栏主题*

[特性亮点](#-核心特性与深度优化) • [预置套件](#-预置功能与套件清单) • [刷机指引](#-固件产物与刷机指引) • [编译说明](#-手动编译与自定义配置) • [鸣谢](#-鸣谢与开源项目)

</div>

---

## 🌟 核心特性与深度优化

本项目基于 **[0x5826/immortalwrt-mtk](https://github.com/0x5826/immortalwrt-mtk)**（活跃开发分支 `openwrt-25.12`，Linux 内核 6.12）构建，针对 BPi-R4 的硬件架构与主路由使用场景进行了深度调优：

### 1. ⚡ 硬件流表 PPE 极致扩容（32,768 条目）
- **性能飞跃**：默认 MTK Filogic 的硬件流表（PPE FOE）为 16,384 条。本项目注入专有内核驱动补丁，将其扩容至 **32,768** 项！
- **效果**：在面对家庭/企业海量并发连接、PT 下载、万兆跨网段 NAT 转发时，硬件卸载流表永不爆满，CPU 占用率无限趋近于 0%，尽显 Filogic 880 硬件怪兽本色。

### 2. 🔇 内核调试噪音过滤
- **日志清爽**：打入内核级补丁，将 MT7988 平台在 `dmesg` 中高频刷屏的 `Couldn't update frequency transition information`（devfreq cci warning）转为 debug 级别，保持系统内核日志干净，便于诊断关键硬件故障。

### 3. 🎨 现代精致 UI：[luci-theme-shadcn](https://github.com/eamonxg/luci-theme-shadcn)
- **告别审美疲劳**：默认预装基于 **shadcn/ui** 设计规范重构的现代化侧边栏主题；
- **全平台自适应**：支持左侧可收起多级导航、深度暗黑模式（Dark Mode）、精致的高清图标与紧凑布局；
- **双重兜底**：内置 `luci-theme-argon` 与 `bootstrap` 作为备用主题。

### 4. 💾 M.2 NVMe 固态硬盘与完整存储生态
- **存储自由**：原生编译启用 `kmod-nvme`，完美识别 BPi-R4 板载 M.2 Key-M PCIe 插槽上的 NVMe 固态硬盘；
- **文件系统支持**：集成 `ext4`、`btrfs`、`f2fs`、`exFAT`、`FAT32` 全套磁盘工具（`btrfs-progs`, `smartmontools`, `fdisk`, `parted` 等）；
- **轻 NAS 共享**：预置高吞吐版本 **Samba4**（支持 SMB 2/3、多通道加速）以及 **Diskman** 磁盘挂载面板。

### 5. 🌐 纯有线万兆主路由定制（剔除负优化）
- **射频开销清零**：彻底屏蔽并剔除 `mt76`、`mt7915`、`mt7996`、`hostapd`、`wpad` 等所有无线驱动及固件，杜绝任何 Wi-Fi 中断争抢与内存开销；
- **拒绝玄学脚本**：移除了在 4GB DDR4 大内存设备上反而导致磁盘 I/O 下降的“清理内存 (ramfree)”插件，屏蔽了不必要的定时重启，让系统长期无缝运行数月无须打扰。

### 6. 🚀 极致 CI/CD 效能
- **极速编译**：引入 **Ccache** 编译缓存与 **dl 源码包持久化**，后续构建耗时从 3 小时以上大幅压减至 **25~35 分钟**；
- **自动化发布**：每次编译自动生成专属带有校验码的 GitHub Releases，提供直链下载，无需面对庞大的 Artifacts 压缩包。

---

## 📦 预置功能与套件清单

| 类别 | 预置插件 / 工具 | 说明与典型用途 |
| :--- | :--- | :--- |
| **网络分流** | `luci-app-mosdns` (v5) | 高性能 DNS 分流与去广告，全中文图形化管理界面 |
| **透明代理** | `luci-app-openclash` | 强力透明代理客户端，集成 TProxy 与 TUN 核心支持 |
| **内网穿透** | `luci-app-lucky` | 官方 Lucky 核心，支持动态域名 DDNS、反向代理、端口转发与 WebDAV |
| **异地组网** | `luci-app-easytier` | 去中心化 Mesh 组网神器，支持跨广域网点对点组网 |
| **虚拟局域网** | `luci-app-zerotier` | 经典 P2P 内网穿透与跨地域组网 |
| **文件共享** | `luci-app-samba4` | 高性能网络共享服务，支持 Apple/Windows 本地挂载 |
| **磁盘管理** | `luci-app-diskman` | 磁盘分区、格式化、挂载管理及 S.M.A.R.T. 健康检查 |
| **吞吐测速** | `luci-app-netspeedtest` | 网页端一键 Web 测速与 iPerf3 高性能测速服务端 |
| **链路监控** | `luci-app-sfp-info` | 实时查看双 10G SFP+ 光电模块温度、电压、接收光功率 |
| **指标采集** | `prometheus-node-exporter-lua` | 系统性能与网络流量指标暴露，配合 Home Assistant / Grafana 监控 |
| **系统运维** | `luci-app-ttyd` | 浏览器内嵌免密/带密 Web 终端 Shell |
| **内核日志** | `luci-app-log` | 实时滚动系统日志与内核 dmesg 查看器（带颜色高亮与正则过滤） |
| **端口映射** | `luci-app-upnp` / `luci-app-socat` | 迷你 UPnP 自动端口映射与双向端口转发套件 |
| **现代界面** | `luci-theme-shadcn` | 默认主题：现代 Shadcn UI 风格可折叠侧边栏 |

---

## 📁 固件产物与刷机指引

### 1. 常见文件辨析

每次 GitHub Actions 编译成功后，将在 [Releases 页面](https://github.com/Apocalypse-Long/bpi-r4-builder/releases) 输出以下核心制品：

| 文件名称匹配 | 适用场景与刷机方法 |
| :--- | :--- |
| `*sdcard.img.gz` | **MicroSD 卡镜像**：初次折腾或想把系统装在 TF 卡上时使用。<br>解压后使用 **Rufus** 或 **Etcher** 写入 MicroSD 卡即可。 |
| `*sysupgrade.itb` | **在线升级固件**：已进入 OpenWrt 系统的常规升级。<br>在 Web 后台 `系统 -> 备份/升级 -> 刷写新的固件` 处直接上传即可。 |
| `*emmc-preloader.bin`<br>`*emmc-bl31-uboot.fip` | **eMMC 引导套件**：写入 BPi-R4 板载 8GB eMMC 的引导程序。 |
| `SHA256SUMS` | **校验和文件**：刷机前请核对固件文件的 SHA256，防止传输损坏变砖。 |

### 2. BPi-R4 硬件启动拨码开关说明 (Boot Select)

BPi-R4 主板上带有 3-pin 拨码开关（标有 `1 2 3` 或对应模式），用于选择启动介质：

| 引导介质模式 | 拨码 1 | 拨码 2 | 拨码 3 | 说明 |
| :---: | :---: | :---: | :---: | :--- |
| **MicroSD (TF卡) 启动** | 0 | 0 | 1 | 烧录 `sdcard.img.gz` 插入卡槽后首选用此模式测试与启动 |
| **eMMC 板载闪存启动** | 0 | 1 | 0 | 固件写入 eMMC 后的日常稳定启动模式 |
| **SPI-NAND 启动** | 0 | 1 | 1 | 板载 SPI NAND 存储启动 |

> [!TIP]
> 推荐路线：先将拨码设为 `0 0 1`，用 TF 卡刷入 `sdcard.img.gz` 正常启动，确认网络与插件一切正常后，再通过命令行或引导脚本将系统安装到板载 eMMC 或 M.2 NVMe SSD。

### 3. 默认网络与后台参数

- **默认后台地址**：`192.168.1.1`
- **默认用户**：`root`
- **默认密码**：无密码（初次登录直接回车，建议登录后立即修改）
- **默认网口定义**：
  - 双 10G SFP+ 光口默认作为高速 WAN / LAN；
  - 4 个千兆网口默认为常规 LAN 交换口。

---

## 🛠️ 手动编译与自定义配置

### 1. 触发云端自动构建
1. Fork 本项目到你自己的 GitHub 账号；
2. 进入你 Fork 的仓库，点击 **Actions**；
3. 在左侧选中 **Build Banana Pi BPi-R4 Firmware**；
4. 点击右侧 **Run workflow**：
   - **选择 0x5826 源码分支**：默认推荐 `openwrt-25.12`（基于 Linux 6.12，包含最新 Filogic 补丁）；
   - **是否发布到 GitHub Releases**：勾选后会自动创建 Release 并归档固件。

### 2. 自定义配置指南
* **增删预置软件包**：修改根目录下的 `bpir4.config` 文件；
* **注入额外内核/系统补丁**：将 `.patch` 文件放入 `patches/` 目录中。
  > 工作流会自动判断：若为驱动底层补丁（`drivers/` 等）会自动派发到 `target/linux/mediatek/patches-*`；若为基础补丁会自动在源码根目录打入。
* **自定义预置配置文件**：如需开箱自带网络规则或网络配置，可在根目录下创建 `files/` 文件夹（例如 `files/etc/config/network`），编译时将自动合并进系统固件。

---

## 📜 鸣谢与开源项目

- [0x5826/immortalwrt-mtk](https://github.com/0x5826/immortalwrt-mtk) - 专为 MTK Filogic 维护的高质量分支
- [ImmortalWrt 官方社区](https://github.com/immortalwrt/immortalwrt) & [OpenWrt 官方项目](https://github.com/openwrt/openwrt)
- [eamonxg/luci-theme-shadcn](https://github.com/eamonxg/luci-theme-shadcn) - 现代化 shadcn/ui 侧边栏主题
- [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) - MosDNS v5 中文管理套件
- [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky) - Lucky 软硬路由内网穿透利器
- [EasyTier](https://github.com/EasyTier/luci-app-easytier) - 优秀的去中心化 Mesh 组网工具