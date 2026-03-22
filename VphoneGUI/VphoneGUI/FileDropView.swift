//
//  FileDropView.swift
//  VphoneGUI
//
//  Created by ArtiSheng on 2026/3/22.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileDropView: View {
    @AppStorage("sshPort") private var sshPort: String = "2222"
    @AppStorage("scpRemotePath") private var scpRemotePath: String = "/var/mobile/Documents/"
    @AppStorage("vphonePath") private var vphonePath: String = "/Users/artisheng/iPhone/vphone-cli"

    @State private var isTargeted = false
    @State private var transferLog: [TransferEntry] = []
    @State private var isTransferring = false

    struct TransferEntry: Identifiable {
        let id = UUID()
        let fileName: String
        var status: Status
        let time: Date

        enum Status {
            case transferring, success, failed(String)

            var icon: String {
                switch self {
                case .transferring: return "arrow.up.circle"
                case .success: return "checkmark.circle.fill"
                case .failed: return "xmark.circle.fill"
                }
            }
            var color: Color {
                switch self {
                case .transferring: return .orange
                case .success: return .green
                case .failed: return .red
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("文件传输")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if isTransferring {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: NSColor(white: 0.15, alpha: 1)))

            Divider().background(Color.orange.opacity(0.3))

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.orange : Color.white.opacity(0.15),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.orange.opacity(0.1) : Color.clear)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)

                VStack(spacing: 12) {
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.up.doc")
                        .font(.system(size: 36))
                        .foregroundStyle(isTargeted ? .orange : .gray)
                        .animation(.easeInOut, value: isTargeted)

                    Text(isTargeted ? "松开即可传输" : "拖拽文件到此处")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isTargeted ? .orange : .gray)

                    Text("文件将通过 SCP 传输到虚拟 iPhone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            // Remote path config
            HStack(spacing: 6) {
                Text("远程路径:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("/var/mobile/Documents/", text: $scpRemotePath)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))

            Divider().background(Color.white.opacity(0.1))

            // Transfer log
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    if transferLog.isEmpty {
                        Text("暂无传输记录")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                            .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(transferLog) { entry in
                                HStack(spacing: 6) {
                                    Image(systemName: entry.status.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(entry.status.color)
                                    Text(entry.fileName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(timeString(entry.time))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(8)
                    }
                }
                .onChange(of: transferLog.count) {
                    if let last = transferLog.last {
                        proxy.scrollTo(last.id)
                    }
                }
            }
            .frame(maxHeight: 150)
            .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? Color.orange.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let fileName = url.lastPathComponent
                let localPath = url.path

                DispatchQueue.main.async {
                    let entry = TransferEntry(fileName: fileName, status: .transferring, time: Date())
                    transferLog.append(entry)
                    transferFile(localPath: localPath, fileName: fileName, entryId: entry.id)
                }
            }
        }
    }

    private func transferFile(localPath: String, fileName: String, entryId: UUID) {
        isTransferring = true

        let iproxyPath = vphonePath + "/.limd/bin/iproxy"
        let cmd = "scp -P \(sshPort) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \"\(localPath)\" mobile@127.0.0.1:\(scpRemotePath)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // sshpass 自动输入 SSH 密码
        process.arguments = ["-c", "sshpass -p alpine \(cmd)"]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                if let idx = transferLog.firstIndex(where: { $0.id == entryId }) {
                    if proc.terminationStatus == 0 {
                        transferLog[idx].status = .success
                    } else {
                        let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? "未知错误"
                        transferLog[idx].status = .failed(errStr)
                    }
                }
                isTransferring = false
            }
        }

        do {
            try process.run()
        } catch {
            if let idx = transferLog.firstIndex(where: { $0.id == entryId }) {
                transferLog[idx].status = .failed(error.localizedDescription)
            }
            isTransferring = false
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
