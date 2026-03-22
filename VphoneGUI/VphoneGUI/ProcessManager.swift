//
//  ProcessManager.swift
//  VphoneGUI
//
//  Created by ArtiSheng on 2026/3/22.
//

import Foundation
import SwiftUI

@Observable
final class ProcessManager {
    var output: String = ""
    var isRunning: Bool = false
    var statusText: String = "空闲"

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    func run(command: String, args: [String] = [], workingDirectory: String? = nil, sudoPassword: String? = nil) {
        guard !isRunning else { return }

        output = ""
        isRunning = true
        statusText = "运行中..."

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        // 构建 shell 命令
        var shellCommand: String
        var extraEnv: [String: String] = [:]

        if let sudoPassword = sudoPassword, !sudoPassword.isEmpty {
            // 通过环境变量传递密码，脚本内部用 echo | sudo -S 读取
            extraEnv["SUDO_PASSWORD"] = sudoPassword
        }

        // 直接执行命令，不包装 sudo（由脚本自身处理 sudo）
        if args.isEmpty {
            shellCommand = command
        } else {
            shellCommand = command + " " + args.map { "\"\($0)\"" }.joined(separator: " ")
        }

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", shellCommand]

        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            NSHomeDirectory() + "/Library/Python/3.9/bin"
        ]
        if let existingPath = env["PATH"] {
            env["PATH"] = extraPaths.joined(separator: ":") + ":" + existingPath
        }
        // 合并额外环境变量（如 SUDO_ASKPASS）
        for (key, value) in extraEnv {
            env[key] = value
        }
        process.environment = env

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        // Read stdout
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                let cleaned = Self.stripANSI(str)
                DispatchQueue.main.async {
                    self?.output += cleaned
                    self?.trimOutputIfNeeded()
                }
            }
        }

        // Read stderr
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                let cleaned = Self.stripANSI(str)
                DispatchQueue.main.async {
                    self?.output += cleaned
                    self?.trimOutputIfNeeded()
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.isRunning = false
                let code = proc.terminationStatus
                if code == 0 {
                    self?.statusText = "已完成 ✓"
                } else if code == 15 || code == 9 {
                    self?.statusText = "已停止"
                } else {
                    self?.statusText = "退出码: \(code)"
                }
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.errorPipe?.fileHandleForReading.readabilityHandler = nil
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.output += "\n❌ 启动失败: \(error.localizedDescription)\n"
                self?.isRunning = false
                self?.statusText = "启动失败"
            }
        }
    }

    func stop() {
        guard let process = process, process.isRunning else { return }
        process.interrupt()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.terminate()
            }
        }
    }

    func sendInput(_ text: String) {
        guard isRunning, let inputPipe = inputPipe else { return }
        if let data = (text + "\n").data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
    }

    func clear() {
        output = ""
    }

    private func trimOutputIfNeeded() {
        // Keep output under 100K characters to avoid memory issues
        if output.count > 100_000 {
            let startIndex = output.index(output.endIndex, offsetBy: -80_000)
            output = "... (旧输出已截断) ...\n" + String(output[startIndex...])
        }
    }

    private static func stripANSI(_ string: String) -> String {
        // Remove common ANSI escape sequences
        let pattern = "\\x1B\\[[0-9;]*[A-Za-z]|\\x1B\\([A-Za-z]|\\x1B\\]\\d+;[^\\x07]*\\x07"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        return regex.stringByReplacingMatches(
            in: string,
            range: NSRange(string.startIndex..., in: string),
            withTemplate: ""
        )
    }
}
