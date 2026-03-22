# VphoneGUI

macOS 桌面应用，用于管理 [vphone-cli](https://github.com/nicklama/vphone-cli) 虚拟 iPhone 环境。

提供三面板一体化界面：**AMFI 绕过** · **虚拟机启动** · **拖拽文件传输**。

## 截图

![VphoneGUI 界面](VphoneGUI/%E5%9B%BE%E7%89%87/1.png)

## 功能

| 面板 | 功能 | 说明 |
|---|---|---|
| **AMFI 绕过** | 一键启动 amfidont daemon | 自动提取 CDHash，sudo 密码本地持久化 |
| **虚拟机启动** | `make boot` 启动虚拟 iPhone | 自动启动 iproxy 端口转发 |
| **文件传输** | 拖拽文件到虚拟机 | SCP 传输，支持自定义远程路径 |

### 附加功能

- ⚡ **一键启动**：AMFI → 虚拟机，全自动
- 🧹 **清理旧进程**：一键杀掉残留 vphone-cli 进程，解决 VM 锁定
- 🔑 **密码持久化**：sudo 密码输入一次，自动保存本地
- 📡 **后台 iproxy**：启动虚拟机后自动建立 SSH 端口转发

## 环境要求

- macOS 15+ (Sequoia)，Apple Silicon
- Xcode 16+
- [vphone-cli](https://github.com/Lakr233/vphone-cli) 已配置
- `amfidont` 已安装 (`xcrun python3 -m pip install --user amfidont`)
- SIP 已关闭 或 `allow-research-guests` 已启用

## 构建 & 运行

```bash
# 用 Xcode 打开
open VphoneGUI/VphoneGUI.xcodeproj

# 或命令行构建
cd VphoneGUI/VphoneGUI
xcodebuild -scheme VphoneGUI -configuration Debug build
```

> ⚠️ 首次运行需在 Xcode 中运行（⌘R），App Sandbox 已禁用以支持外部命令执行。

## 使用流程

1. 输入 sudo 密码（首次，后续自动记住）
2. 点击 **AMFI 启动**（或「一键启动」）
3. 等待 daemon 启动后，点击 **虚拟机启动**
4. 虚拟机就绪后，拖拽文件到右侧面板即可传输

> 💡 重启 Mac 后需重新启动 AMFI 绕过。虚拟机关闭再启动不需要。

## 项目结构

```
VphoneGUI/
├── VphoneGUI/
│   ├── ContentView.swift      # 主界面三面板布局
│   ├── ProcessManager.swift   # 进程管理（stdin/stdout/stderr）
│   ├── TerminalView.swift     # 终端输出显示组件
│   ├── FileDropView.swift     # 拖拽文件传输组件
│   ├── VphoneGUIApp.swift     # App 入口
│   └── scripts/
│       └── start_amfidont.sh  # AMFI 绕过脚本
└── VphoneGUI.xcodeproj/
```

## 开源许可

本项目采用 **GNU 通用公共许可证 v3.0（GPLv3）** 许可证。这意味着您可以自由使用、修改和分发本软件，但是：

- 任何基于本软件的衍生作品必须以相同的许可证发布
- 必须保留原始版权声明
- 您必须明确说明您对原始代码所做的任何更改

详细许可条款请参阅项目根目录下的 [LICENSE](LICENSE) 文件。
