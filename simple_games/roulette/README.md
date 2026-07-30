#The Chinese is for personal use, to make future optimizations easier, so I hope you don't mind.
#Besides, For the game Demon Roulette, the frontend code is quite heavy in terms of logic and is still being optimized. Please refer to terminal_game.py for the frontend.
# 恶魔轮盘赌 / Buckshot Roulette

## 打开方式

### 终端版（推荐）
```bash
cd roulette
python terminal_game.py
```

### 原始单文件版
直接用浏览器打开 `buckshot-roulette.html`（无需服务器）

## 操作

终端版操作：

| 按键 | 操作 |
|------|------|
| 1 | 向庄家开枪 |
| 2 | 向自己开枪 |
| 3 | 使用道具（然后输入编号） |
| 0 | 返回（道具选择时） |

## 游戏规则

### 基本规则
- 你和庄家各 3 条命，共 3 个回合
- 每回合一把霰弹枪，弹膛里随机装有实弹和空弹
- 玩家永远先手

### 你的回合可以：
- **向庄家开枪**：实弹扣庄家血，空弹换庄家行动
- **向自己开枪**：实弹扣自己血换庄家，空弹自己继续
- **使用道具**：使用后不消耗行动机会

### 道具清单
| 道具 | 图标 | 效果 |
|------|------|------|
| 放大镜 | O | 查看当前子弹是实弹还是空弹 |
| 啤酒 | U | 退出当前子弹（不发射） |
| 手铐 | C | 对手跳过下一回合 |
| 香烟 | S | 恢复 1 点生命值（上限 3） |
| 锯子 | W | 下一发实弹造成 2 倍伤害 |
| 逆变器 | I | 翻转当前子弹（实弹变空弹，空弹变实弹） |

### 胜负判定
- 一方生命归零：对方赢得本回合
- 弹膛打空：平局
- 3 回合后生命多者获胜

---

# Buckshot Roulette

## How to Run

### Terminal (Recommended)
```bash
cd roulette
python terminal_game.py
```

### Standalone HTML
Open `buckshot-roulette.html` directly in your browser. No server needed.

## Controls

Terminal controls:

| Key | Action |
|-----|--------|
| 1 | Shoot the dealer |
| 2 | Shoot yourself |
| 3 | Use item (then enter item number) |
| 0 | Back (when selecting items) |

## Game Rules

### Basic Rules
- You and the dealer each have 3 lives, 3 rounds total
- Each round: one shotgun loaded with random live and blank shells
- Player always goes first

### On Your Turn:
- **Shoot the dealer**: Live round damages dealer then switches turn. Blank switches turn.
- **Shoot yourself**: Live round damages you then switches turn. Blank lets you continue.
- **Use item**: Does not consume your action

### Items
| Item | Icon | Effect |
|------|------|--------|
| Magnifier | O | Inspect the current shell |
| Beer | U | Eject the current shell without firing |
| Cuffs | C | Opponent skips their next turn |
| Cigarette | S | Restore 1 HP (max 3) |
| Saw | W | Next live shell deals double damage |
| Inverter | I | Flip the current shell (live <-> blank) |

### Win/Loss
- One side's HP reaches 0: opponent wins the round
- Chamber empty: draw
- After 3 rounds, whoever has more HP wins the game
