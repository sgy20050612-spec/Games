# 超级马里奥 / Terminal Mario

## 打开方式

### 终端版
```bash
cd mario
python mario_terminal.py
```

### 前端版（推荐）
双击用浏览器打开 `mario_frontend.html`，无需安装任何依赖。

## 操作

| 按键 | 操作 |
|------|------|
| A / ← | 向左移动 |
| D / → | 向右移动 |
| W / 空格 / ↑ | 跳跃 |
| R | 重新开始（仅前端版） |
| Q | 退出（仅终端版） |

## 游戏规则

### 关卡设计
共 3 关，难度递增：
- 第 1 关：4 个平台，3 个敌人，4 个金币
- 第 2 关：5 个平台，4 个敌人，5 个金币
- 第 3 关：7 个平台，6 个敌人，7 个金币

### 物理机制
- 重力加速度：0.02（前端）/ 0.05（终端）
- 跳跃高度：约 5 格
- 水平移动速度：0.08（前端）/ 1.0（终端）
- 踩敌人后弹跳：0.26（前端）

### 敌人
- 敌人沿平台来回巡逻（左右移动）
- 碰到敌人身体会扣一条命
- 从敌人**正上方踩下**可以消灭敌人

### 金币
- 散布在各平台的固定位置
- 必须收集**当前关卡全部金币**后，旗帜才会出现
- 收集金币获得 100 分

### 旗帜
- 到达旗帜位置并触碰即可过关
- 通关获得 500 分

### 生命
- 共 3 条命
- 碰到敌人：扣 1 命
- 掉落出屏幕底部：扣 1 命
- 生命耗尽：游戏结束

---

# Super Mario / Terminal Mario

## How to Run

### Terminal
```bash
cd mario
python mario_terminal.py
```

### Browser (Recommended)
Open `mario_frontend.html` directly in your browser. No dependencies required.

## Controls

| Key | Action |
|-----|--------|
| A / ← | Move Left |
| D / → | Move Right |
| W / Space / ↑ | Jump |
| R | Restart (Browser only) |
| Q | Quit (Terminal only) |

## Game Rules

### Level Design
3 levels with increasing difficulty:
- Level 1: 4 platforms, 3 enemies, 4 coins
- Level 2: 5 platforms, 4 enemies, 5 coins
- Level 3: 7 platforms, 6 enemies, 7 coins

### Physics
- Gravity: 0.02 (browser) / 0.05 (terminal)
- Jump height: ~5 cells
- Horizontal speed: 0.08 (browser) / 1.0 (terminal)
- Stomp bounce: 0.26 (browser)

### Enemies
- Enemies patrol back and forth on platforms
- Touching an enemy costs 1 life
- Landing on an enemy from **directly above** defeats them

### Coins
- Scattered at fixed positions on platforms
- The flag only appears after collecting **all coins** in the current level
- Collecting a coin gives 100 points

### Flag
- Reach and touch the flag to complete the level
- Level completion gives 500 points

### Lives
- 3 lives total
- Touching an enemy: lose 1 life
- Falling off screen bottom: lose 1 life
- All lives lost: game over
