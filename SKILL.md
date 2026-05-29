---
name: openpet-complete-setup
description: 
  从零开始完整配置 OpenPet 桌宠与 Hermes Agent 的联动。
  包含 WSL 路径修复、自动钩子安装、看门狗配置、Cron 定时任务等完整流程。
  适用于 Windows + WSL 环境下的 Hermes Agent 用户。
version: "1.0.0"
author: MorDream
category: productivity
tags: [openpet, desktop-pet, wsl, hermes, setup, companion]
---

# OpenPet 完整配置指南

从零开始配置 OpenPet 桌宠与 Hermes Agent 的完整联动方案。

## 概述

本 Skill 提供从安装到完整配置的完整流程，包括：
- OpenPet 桌面端安装
- WSL 路径问题修复
- Hermes Agent 自动钩子安装
- 看门狗自动启动配置
- Cron 定时任务设置

## 前置要求

- Windows 10/11
- WSL2 + Ubuntu
- Hermes Agent 已安装
- OpenPet 已下载

## 安装步骤

### 步骤 1: 安装 OpenPet

1. 下载 OpenPet: https://github.com/X-T-E-R/OpenPet/releases
2. 解压到 `C:\Users\<用户名>\AppData\Local\OpenPet\`
3. 手动运行一次 `openpet.exe`，确保能正常启动

### 步骤 2: 创建核心钩子模块

创建文件 `~/.hermes/hermes-agent/tools/openpet_hook.py`:

```python
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
```

### 步骤 3: 安装自动钩子

#### 3.1 修改 `tools/file_tools.py`

在文件顶部添加 import:
```python
from tools.openpet_hook import send_openpet_event
```

在 `_handle_read_file()` 函数开头添加:
```python
send_openpet_event("reviewing", "📖 正在读取文件...")
```

在 `_handle_write_file()` 函数开头添加:
```python
send_openpet_event("tool-running", "✍️ 正在写入文件...")
```

在 `_handle_patch()` 函数开头添加:
```python
send_openpet_event("tool-running", "🔧 正在修改文件...")
```

在 `_handle_search_files()` 函数开头添加:
```python
send_openpet_event("reviewing", "🔎 正在搜索文件...")
```

#### 3.2 修改 `tools/code_execution_tool.py`

在文件顶部添加 import:
```python
from tools.openpet_hook import send_openpet_event
```

在 `execute_code` 函数开头添加:
```python
send_openpet_event("tool-running", "🐍 正在执行代码...")
```

#### 3.3 修改 `tools/terminal_tool.py`

在文件中找到 `_execute_command` 函数，在其定义前添加:

```python
def _send_openpet_pre_hook():
    """Pre-execution hook: send 'tool-running' event to OpenPet desk pet."""
    try:
        import urllib.request
        import json
        payload = json.dumps({
            "type": "tool-running",
            "message": "🏃 正在执行命令...",
            "ttlMs": 3000,
        }).encode("utf-8")
        req = urllib.request.Request(
            "http://127.0.0.1:17321/api/event",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=1)
    except Exception:
        pass  # OpenPet not running — silently ignore
```

在 `_execute_command` 函数开头调用:
```python
_send_openpet_pre_hook()  # 🔌 OpenPet hook: auto-notify before every terminal call
```

#### 3.4 修改 `tools/approval.py`

在 CLI 路径（约第 1383-1389 行）添加:
```python
# Notify OpenPet desk pet about security approval
try:
    from tools.openpet_hook import send_openpet_event
    send_openpet_event("attention", f"⚠️ 审批：{combined_desc[:60]}", 5000)
except ImportError:
    pass
```

在 Gateway 路径（约第 1215-1220 行）添加:
```python
# Notify OpenPet desk pet about security approval (gateway)
try:
    from tools.openpet_hook import send_openpet_event
    send_openpet_event("attention", f"⚠️ 审批中(网关)：{combined_desc[:60]}", 5000)
except ImportError:
    pass
```

### 步骤 4: 创建看门狗脚本

创建文件 `~/.hermes/scripts/openpet-watchdog.sh`:

```bash
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
```

赋予执行权限:
```bash
chmod +x ~/.hermes/scripts/openpet-watchdog.sh
```

### 步骤 5: 创建快捷命令

创建文件 `~/.local/bin/openpet`:

```bash
#!/bin/bash
# OpenPet 快捷命令 - 让 Hermes 一键更新桌宠状态
# 用法: openpet <event_type> [消息]
# 事件: thinking, running, reviewing, success, failure, attention
# 也可用: say <text> [ttl], action <animation>

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
  think|thinking)
    send_event "thinking" "${2:-思考中...🤔}" "$3"
    ;;
  run|running|tool)
    send_event "tool-running" "${2:-正在运行...🏃}" "$3"
    ;;
  review|reviewing)
    send_event "reviewing" "${2:-正在审查中...🔍}" "$3"
    ;;
  success|done|ok)
    send_event "success" "${2:-搞定！🎉}" "$3"
    send_action "jumping"
    ;;
  fail|failure|error)
    send_event "failure" "${2:-出问题了😢}" "$3"
    send_action "failed"
    ;;
  attention|hey|look)
    send_event "attention" "${2:-看这里！👋}" "$3"
    send_action "waving"
    ;;
  say|talk)
    send_say "${2:-你好呀～🦖}" "$3"
    ;;
  jump|dance)
    send_action "jumping"
    ;;
  wave)
    send_action "waving"
    ;;
  status)
    curl -s "$API/api/status" | python3 -c "
import json,sys
d=json.load(sys.stdin)
p=d['activePet']
print(f\"当前宠物: {p['displayName']} ({p['id']})\")
print(f\"气泡: {d.get('bubbleText','无')}\")
print(f\"最近事件: {len(d.get('recentEvents',[]))}个\")
"
    ;;
  *)
    echo "用法: openpet <事件> [消息] [ttl_ms]"
    echo ""
    echo "事件类型:"
    echo "  think|thinking    💭 思考中..."
    echo "  run|running       🏃 运行中..."
    echo "  review|reviewing  🔍 审查中..."
    echo "  success|done      🎉 完成！(自动跳跃)"
    echo "  fail|failure      😢 出错了"
    echo "  attention|hey     👋 需要关注"
    echo "  say|talk          🗨️ 说话气泡"
    echo "  jump|dance        🕺 跳跃动画"
    echo "  wave              👋 挥手动画"
    echo "  status            📊 查看当前状态"
    ;;
esac
```

赋予执行权限:
```bash
chmod +x ~/.local/bin/openpet
```

### 步骤 6: 配置 Cron 定时任务

使用 Hermes CLI 创建看门狗定时任务:

```bash
hermes cron create "every 1m" --name "OpenPet 桌宠看门狗" --script openpet-watchdog.sh --no-agent --deliver local
```

或者手动编辑 `~/.hermes/cron/jobs.json`:

```json
{
  "jobs": [
    {
      "job_id": "openpet-watchdog",
      "name": "OpenPet 桌宠看门狗",
      "prompt": "OpenPet watchdog — 检测桌宠是否运行，没跑就自动启动",
      "schedule": "every 1m",
      "script": "openpet-watchdog.sh",
      "no_agent": true,
      "deliver": "local",
      "enabled": true
    }
  ]
}
```

### 步骤 7: 重启 Hermes

修改后需要重启 Hermes 会话:
```bash
# 退出当前会话
exit

# 重新启动
hermes
```

## 验证安装

### 测试 1: 手动发送事件

```bash
openpet think "测试思考事件"
openpet run "测试运行事件"
openpet success "测试成功事件"
```

### 测试 2: 测试自动钩子

在 Hermes 中执行:
```
读取一个文件，比如:
read_file path="~/.bashrc"
```

观察 OpenPet 是否显示"📖 正在读取文件..."

### 测试 3: 测试看门狗

1. 关闭 OpenPet
2. 等待 1 分钟
3. 观察 OpenPet 是否自动启动

## 故障排除

### 问题 1: Windows 找不到文件弹窗

**原因**: WSL 路径格式不正确

**解决**: 确保看门狗脚本使用 `wslpath -w` 转换路径:
```bash
OPENPET_WIN=$(wslpath -w "$OPENPET_EXE")
cmd.exe /c "start $OPENPET_WIN"
```

### 问题 2: 钩子不生效

**原因**: 文件修改后未重启 Hermes

**解决**: 退出并重新启动 Hermes

### 问题 3: OpenPet API 无响应

**原因**: OpenPet 未运行或端口被占用

**解决**: 
```bash
# 检查 OpenPet 状态
curl http://127.0.0.1:17321/api/status

# 手动启动 OpenPet
cmd.exe /c "start C:\Users\<用户名>\AppData\Local\OpenPet\openpet.exe"
```

## 事件类型参考

| 事件类型 | 动画 | 用途 |
|---------|------|------|
| `thinking` | waiting | 开始思考/分析 |
| `tool-running` | running | 执行命令/脚本 |
| `reviewing` | review | 审查代码/结果 |
| `success` | jumping | 任务完成 |
| `failure` | failed | 任务失败 |
| `attention` | waving | 需要用户注意 |

## 相关资源

- OpenPet 项目: https://github.com/X-T-E-R/OpenPet
- Codex Pets: https://codex-pets.net
- Hermes Agent: https://github.com/NousResearch/hermes-agent

## 作者

MorDream - 整理完整配置经验
