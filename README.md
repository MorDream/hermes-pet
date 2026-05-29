# Hermes OpenPet Skill

完整的 OpenPet 桌宠与 Hermes Agent 联动配置方案。

## 快速开始

```bash
# 安装 Skill
hermes skills install https://github.com/MorDream/hermes-pet/blob/main/SKILL.md

# 或手动安装脚本
bash <(curl -s https://raw.githubusercontent.com/MorDream/hermes-pet/main/scripts/install-hooks.sh)
```

## 功能

- ✅ 自动事件触发（读文件、写文件、执行命令等）
- ✅ 看门狗自动启动 OpenPet
- ✅ Cron 定时检查
- ✅ WSL 路径问题修复
- ✅ 快捷命令工具

## 文档

详细配置请参考 [SKILL.md](SKILL.md)

## 环境要求

- Windows 10/11 + WSL2
- Hermes Agent
- OpenPet 桌面端

## License

MIT
