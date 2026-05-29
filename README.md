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

## 桌宠导入方式

### 方式一：从 Codex Pets 导入（推荐）

1. 访问 https://codex-pets.net
2. 浏览并选择喜欢的宠物
3. 点击宠物进入详情页
4. 复制页面上的导入链接
5. 在 OpenPet 中点击"导入网络宠物"，粘贴链接

### 方式二：使用脚本导入（穿墙友好）

使用 skill 中的脚本绕过直接下载：

```bash
# 导入茉莉
cd ~/.hermes/skills/openpet-complete-setup/scripts
bash import_codex_pet.sh sakuraha-emma

# 导入奶龙
bash import_codex_pet.sh nailong0

# 导入耄耆
bash import_codex_pet.sh maodie
```

### 方式三：手动导入本地宠物

1. 准备宠物文件：
   - `pet.json` - 宠物配置
   - `spritesheet.webp` - 宠物图片

2. 放到一个文件夹中，比如 `D:\\Pets\\MyPet\\`

3. 调用 OpenPet API 导入：
```bash
curl -X POST http://127.0.0.1:17321/api/import/local \
  -H "Content-Type: application/json" \
  -d '{"source": "D:\\\\Pets\\\\MyPet"}'
```

### 推荐宠物

| 宠物 ID | 名称 | 特点 |
|---------|------|------|
| `nailong0` | 奶龙 | 黄色圆滚滚小恐龙 |
| `sakuraha-emma` | 樱羽艾玛 | 白发粉色发尾少女 |
| `maodie` | 耄耆 | 真实猫咪表情包 |

## 文档

详细配置请参考 [SKILL.md](SKILL.md)

## 环境要求

- Windows 10/11 + WSL2
- Hermes Agent
- OpenPet 桌面端

## License

MIT
