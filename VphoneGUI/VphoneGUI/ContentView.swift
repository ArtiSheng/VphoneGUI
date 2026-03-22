//
//  ContentView.swift
//  VphoneGUI
//
//  Created by ArtiSheng on 2026/3/22.
//

import SwiftUI

struct ContentView: View {
    // Process managers
    @State private var amfiManager = ProcessManager()
    @State private var bootManager = ProcessManager()
    @State private var iproxyManager = ProcessManager()  // 后台运行，无 UI

    // Config — 用 @AppStorage 持久化保存，下次打开自动读取
    @AppStorage("sudoPassword") private var sudoPassword: String = ""
    @AppStorage("vphonePath") private var vphonePath: String = "/Users/artisheng/iPhone/vphone-cli"
    @AppStorage("sshPort") private var sshPort: String = "2222"
    @AppStorage("scpRemotePath") private var scpRemotePath: String = "/var/mobile/Documents/"

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            topBar

            Divider().background(Color.white.opacity(0.1))

            // Three terminal panels
            HStack(spacing: 1) {
                // Panel 1: AMFI Bypass
                VStack(spacing: 0) {
                    TerminalView(title: "AMFI 绕过", icon: "shield.slash", manager: amfiManager)

                    // sudo 密码输入区域
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)

                        Text("sudo 密码:")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        TextField("输入管理员密码", text: $sudoPassword)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        if !sudoPassword.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                                .help("密码已保存，下次自动使用")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))

                    HStack(spacing: 8) {
                        Button(action: startAmfidont) {
                            Label("启动", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(amfiManager.isRunning || sudoPassword.isEmpty)

                        Button(action: { amfiManager.stop() }) {
                            Label("停止", systemImage: "stop.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .disabled(!amfiManager.isRunning)

                        Button(action: killOldProcesses) {
                            Label("清理旧进程", systemImage: "xmark.bin")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .help("杀掉残留的 vphone-cli 进程，解决 VM 锁定问题")

                        Spacer()

                        Button(action: { amfiManager.clear() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
                }

                // Panel 2: VPhone Boot
                VStack(spacing: 0) {
                    TerminalView(title: "虚拟机启动", icon: "iphone", manager: bootManager)

                    HStack(spacing: 8) {
                        Button(action: startBoot) {
                            Label("启动", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(bootManager.isRunning)

                        Button(action: { bootManager.stop() }) {
                            Label("停止", systemImage: "stop.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bootManager.isRunning)

                        Spacer()

                        Button(action: { bootManager.clear() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
                }

                // Panel 3: 拖拽文件传输
                FileDropView()
                    .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
            }
        }
        .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 18))
                .foregroundStyle(.green)

            Text("VPhone GUI")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // One-click all
            Button(action: startAll) {
                Label("一键启动", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(amfiManager.isRunning && bootManager.isRunning)

            Button(action: stopAll) {
                Label("全部停止", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: NSColor(white: 0.13, alpha: 1)))
    }

    // MARK: - Actions

    private func killOldProcesses() {
        // 杀掉残留的 vphone-cli 进程
        let cmd = "pkill -f vphone-cli 2>/dev/null; echo '\(sudoPassword)' | sudo -S pkill -9 -f vphone-cli 2>/dev/null; echo '[✓] 旧进程已清理'"
        amfiManager.run(command: cmd)
    }

    private func startAmfidont() {
        // 使用 GUI 项目内置的 amfidont 启动脚本
        let amfiScript = vphonePath.replacingOccurrences(
            of: "vphone-cli",
            with: "VphoneGUI/VphoneGUI/VphoneGUI/scripts/start_amfidont.sh"
        )
        amfiManager.run(
            command: "VPHONE_PATH='\(vphonePath)' '\(amfiScript)'",
            sudoPassword: sudoPassword
        )
    }

    private func startBoot() {
        bootManager.run(
            command: "make boot",
            workingDirectory: vphonePath
        )
        // 启动后自动运行 iproxy（后台等待 5 秒让虚拟机初始化）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            startIproxyBackground()
        }
    }

    private func startIproxyBackground() {
        guard !iproxyManager.isRunning else { return }
        let iproxyPath = vphonePath + "/.limd/bin/iproxy"
        iproxyManager.run(command: "\(iproxyPath) \(sshPort) 22")
    }

    private func startAll() {
        startAmfidont()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            startBoot()
        }
    }

    private func stopAll() {
        amfiManager.stop()
        bootManager.stop()
        iproxyManager.stop()
    }
}

#Preview {
    ContentView()
        .frame(width: 1400, height: 700)
}
