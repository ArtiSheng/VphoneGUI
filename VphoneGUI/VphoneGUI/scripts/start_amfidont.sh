#!/bin/zsh
# start_amfidont.sh — 启动 amfidont 绕过 AMFI，适配 VphoneGUI
# 从 vphone-cli/scripts/start_amfidont_for_vphone.sh 复制并适配
#
# 用法: VPHONE_PATH=/path/to/vphone-cli ./start_amfidont.sh
# 如果设置了 SUDO_ASKPASS 环境变量，会使用 sudo -A 自动输入密码

set -euo pipefail

# 从环境变量获取 vphone-cli 路径，默认值
VPHONE_PATH="${VPHONE_PATH:-/Users/artisheng/iPhone/vphone-cli}"
BUNDLE_BIN="${VPHONE_PATH}/.build/vphone-cli.app/Contents/MacOS/vphone-cli"
AMFIDONT_BIN="${HOME}/Library/Python/3.9/bin/amfidont"

# 检查 amfidont
[[ -x "$AMFIDONT_BIN" ]] || {
  echo "❌ amfidont 未找到: $AMFIDONT_BIN" >&2
  echo "   安装: xcrun python3 -m pip install --user amfidont" >&2
  exit 1
}

# 检查 vphone-cli binary
[[ -x "$BUNDLE_BIN" ]] || {
  echo "❌ vphone-cli binary 未找到: $BUNDLE_BIN" >&2
  echo "   请先运行 make bundle" >&2
  exit 1
}

# 提取 CDHash
CDHASH="$(
  codesign -dv --verbose=4 "$BUNDLE_BIN" 2>&1 \
    | sed -n 's/^CDHash=//p' \
    | head -n1
)"
[[ -n "$CDHASH" ]] || {
  echo "⚠️  无法提取 CDHash，将不带 CDHash 运行" >&2
  CDHASH=""
}

AMFI_PATH="${VPHONE_PATH}/.build"

echo "[*] vphone-cli 路径:   $VPHONE_PATH"
echo "[*] AMFI 路径:         $AMFI_PATH"
echo "[*] CDHash:            ${CDHASH:-（无）}"
echo "[*] 启动 amfidont daemon..."

# 构建 amfidont 命令
AMFIDONT_CMD=(
  env PYTHONPATH="/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/Python"
  /usr/bin/python3 "$AMFIDONT_BIN" daemon
  --path "$AMFI_PATH"
  --verbose
)

# 如果有 CDHash 则添加
if [[ -n "$CDHASH" ]]; then
  AMFIDONT_CMD+=(--cdhash "$CDHASH")
fi

# 判断是否有密码环境变量（由 VphoneGUI 传入）
if [[ -n "${SUDO_PASSWORD:-}" ]]; then
  echo "[*] 使用自动认证"
  echo "$SUDO_PASSWORD" | sudo -S "${AMFIDONT_CMD[@]}" 2>&1
else
  echo "[*] 需要手动输入 sudo 密码"
  sudo "${AMFIDONT_CMD[@]}"
fi

# 等待 daemon 进程启动
sleep 1

# 查找 daemon PID 并持续监控
DAEMON_PID=$(pgrep -f "amfidont.*daemon" 2>/dev/null | tail -1)
if [[ -n "$DAEMON_PID" ]]; then
  echo "[✓] amfidont daemon 运行中 (PID: $DAEMON_PID)"
  echo "[*] 监控中... 关闭此面板将终止 daemon"

  # 捕获信号，停止时杀掉 daemon
  trap "echo '[*] 正在停止 daemon...'; echo \"\$SUDO_PASSWORD\" | sudo -S kill $DAEMON_PID 2>/dev/null || kill $DAEMON_PID 2>/dev/null; exit 0" INT TERM

  # 持续监控 daemon 是否存活
  while kill -0 "$DAEMON_PID" 2>/dev/null; do
    sleep 3
  done
  echo "[!] amfidont daemon 已退出"
else
  echo "[!] 未检测到 daemon 进程"
fi
