#!/bin/bash
# OpenPet 自动钩子安装脚本
# 用法: bash install-hooks.sh

set -e

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
TOOLS_DIR="$HERMES_HOME/hermes-agent/tools"

echo "🐼 OpenPet 自动钩子安装脚本"
echo "================================"
echo ""

# 检查目录存在
if [ ! -d "$TOOLS_DIR" ]; then
    echo "❌ 错误: 找不到 Hermes tools 目录: $TOOLS_DIR"
    echo "请确保 Hermes Agent 已正确安装"
    exit 1
fi

echo "✅ 找到 Hermes 安装目录: $HERMES_HOME"
echo ""

# 1. 创建核心钩子模块
echo "[1/6] 创建核心钩子模块..."
cat > "$TOOLS_DIR/openpet_hook.py" << 'EOF'
"""OpenPet event hook — shared module for all tools.

Sends companion events to the OpenPet desk pet HTTP API before
tool execution.  Silently ignored when OpenPet is not running.
"""

import json
import logging

logger = logging.getLogger(__name__)

_OPENPET_URL = "http://127.0.0.1:17321/api/event"


def send_openpet_event(event_type: str = "tool-running",
                       message: str = "🏃 正在执行命令...",
                       ttl_ms: int = 3000) -> None:
    """Send an event to the OpenPet desk pet.  Failures are silently ignored."""
    try:
        import urllib.request
        payload = json.dumps({
            "type": event_type,
            "message": message,
            "ttlMs": ttl_ms,
        }).encode("utf-8")
        req = urllib.request.Request(
            _OPENPET_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=1)
    except Exception:
        pass  # OpenPet not running — silently ignore
EOF
echo "    ✅ 已创建: $TOOLS_DIR/openpet_hook.py"

# 2. 创建看门狗脚本
echo "[2/6] 创建看门狗脚本..."
mkdir -p "$HERMES_HOME/scripts"
cat > "$HERMES_HOME/scripts/openpet-watchdog.sh" << 'EOF'
#!/bin/bash
# 检查 OpenPet 桌宠是否在运行，没运行就自动启动

API_URL="http://127.0.0.1:17321/api/status"
OPENPET_EXE="/mnt/c/Users/$USER/AppData/Local/OpenPet/openpet.exe"

# 1. 先检查 API 是否响应
if curl -sf "$API_URL" > /dev/null 2>&1; then
    exit 0
fi

# 2. API 没响应，检查进程是否存在
if cmd.exe /c "tasklist | findstr openpet.exe" > /dev/null 2>&1; then
    # 进程在但 API 没起来——可能还在启动中，等等看
    for i in 1 2 3 4 5; do
        sleep 2
        if curl -sf "$API_URL" > /dev/null 2>&1; then
            exit 0
        fi
    done
    exit 1
fi

# 3. 啥都没有，启动它（关键：用 wslpath 转换路径，用 start 命令启动）
OPENPET_WIN=$(wslpath -w "$OPENPET_EXE")
cmd.exe /c "start $OPENPET_WIN"

# 4. 等 API 就绪（最多等 15 秒）
for i in 1 2 3 4 5 6 7; do
    sleep 2
    if curl -sf "$API_URL" > /dev/null 2>&1; then
        exit 0
    fi
done

exit 1
EOF
chmod +x "$HERMES_HOME/scripts/openpet-watchdog.sh"
echo "    ✅ 已创建: $HERMES_HOME/scripts/openpet-watchdog.sh"

# 3. 创建快捷命令
echo "[3/6] 创建快捷命令..."
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/openpet" << 'EOF'
#!/bin/bash
# OpenPet 快捷命令 - 让 Hermes 一键更新桌宠状态

API="http://127.0.0.1:17321"
TTL=3000

send_event() {
  local type="$1" msg="$2" ttl="${3:-$TTL}"
  curl -s -X POST "$API/api/event" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"$type\",\"message\":\"$msg\",\"ttlMs\":$ttl}" > /dev/null
}

send_say() {
  local text="$1" ttl="${2:-4000}"
  curl -s -X POST "$API/api/say" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$text\",\"ttlMs\":$ttl}" > /dev/null
}

send_action() {
  local anim="$1"
  curl -s -X POST "$API/api/action" \
    -H "Content-Type: application/json" \
    -d "{\"animationId\":\"$anim\"}" > /dev/null
}

case "$1" in
  think|thinking) send_event "thinking" "${2:-思考中...🤔}" "$3" ;;
  run|running|tool) send_event "tool-running" "${2:-正在运行...🏃}" "$3" ;;
  review|reviewing) send_event "reviewing" "${2:-正在审查中...🔍}" "$3" ;;
  success|done|ok) send_event "success" "${2:-搞定！🎉}" "$3"; send_action "jumping" ;;
  fail|failure|error) send_event "failure" "${2:-出问题了😢}" "$3"; send_action "failed" ;;
  attention|hey|look) send_event "attention" "${2:-看这里！👋}" "$3"; send_action "waving" ;;
  say|talk) send_say "${2:-你好呀～🦖}" "$3" ;;
  jump|dance) send_action "jumping" ;;
  wave) send_action "waving" ;;
  status) curl -s "$API/api/status" | python3 -c "import json,sys; d=json.load(sys.stdin); p=d['activePet']; print(f\"当前宠物: {p['displayName']}\"); print(f\"气泡: {d.get('bubbleText','无')}\")" ;;
  *) echo "用法: openpet <事件> [消息] [选项]"; echo "事件: think, run, review, success, fail, attention, say, jump, wave, status" ;;
esac
EOF
chmod +x "$HOME/.local/bin/openpet"
echo "    ✅ 已创建: $HOME/.local/bin/openpet"

echo ""
echo "⚠️  注意: 请确保 $HOME/.local/bin 在 PATH 中"
echo "   如果不在 PATH 中，请添加到 ~/.bashrc:"
echo '   export PATH="$HOME/.local/bin:$PATH"'
echo ""

# 4. 检查现有工具文件
echo "[4/6] 检查现有工具文件..."

# 检查 file_tools.py
if [ -f "$TOOLS_DIR/file_tools.py" ]; then
    if grep -q "send_openpet_event" "$TOOLS_DIR/file_tools.py"; then
        echo "    ✅ file_tools.py 已有钩子"
    else
        echo "    ⚠️  file_tools.py 需要手动添加钩子"
        echo "       请参考 SKILL.md 中的详细步骤"
    fi
else
    echo "    ❌ 找不到 file_tools.py"
fi

# 检查 terminal_tool.py
if [ -f "$TOOLS_DIR/terminal_tool.py" ]; then
    if grep -q "_send_openpet_pre_hook" "$TOOLS_DIR/terminal_tool.py"; then
        echo "    ✅ terminal_tool.py 已有钩子"
    else
        echo "    ⚠️  terminal_tool.py 需要手动添加钩子"
    fi
else
    echo "    ❌ 找不到 terminal_tool.py"
fi

# 检查 code_execution_tool.py
if [ -f "$TOOLS_DIR/code_execution_tool.py" ]; then
    if grep -q "send_openpet_event" "$TOOLS_DIR/code_execution_tool.py"; then
        echo "    ✅ code_execution_tool.py 已有钩子"
    else
        echo "    ⚠️  code_execution_tool.py 需要手动添加钩子"
    fi
else
    echo "    ❌ 找不到 code_execution_tool.py"
fi

# 检查 approval.py
if [ -f "$TOOLS_DIR/approval.py" ]; then
    if grep -q "send_openpet_event" "$TOOLS_DIR/approval.py"; then
        echo "    ✅ approval.py 已有钩子"
    else
        echo "    ⚠️  approval.py 需要手动添加钩子"
    fi
else
    echo "    ❌ 找不到 approval.py"
fi

echo ""
echo "[5/6] 创建 Cron 任务..."
echo "    请手动运行: hermes cron create \"every 1m\" --name \"OpenPet 看门狗\" --script openpet-watchdog.sh --no-agent --deliver local"

echo ""
echo "[6/6] 安装完成！"
echo ""
echo "📝 下一步:"
echo "   1. 确保 OpenPet 已安装在 C:\Users\$USER\AppData\Local\OpenPet\"
echo "   2. 手动添加钩子到各个工具文件（如果还没添加）"
echo "   3. 重启 Hermes 会话使配置生效"
echo "   4. 运行 'openpet status' 测试连接"
echo ""
echo "📖 详细文档请参考: hermes skills inspect openpet-complete-setup"
