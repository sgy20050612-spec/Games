"""
================================================================================
  终端版超级马里奥
  运行: python mario_terminal.py
  操作: A/D 移动, W 跳跃, Q 退出q
================================================================================
"""
"""
================================================================================
  整体设计思路

  我做这个游戏的时候，把整个系统拆成了五个独立的组件，每个组件只负责一件事。
  这样改关卡、调手感、换渲染都不会互相影响。

  一、Player 类 — 玩家角色
      这是整个游戏的核心,我在这里实现了物理引擎。玩家的位置由两个分量驱动:
      x 分量来自输入(按 A 或 D),y 分量来自重力和跳跃的合力。每一帧把这两个分量
      合并成一个向量 (vx, vy),驱动位置更新。碰撞检测只在下落时生效(vy 大于等于 0),
      这样就不会阻止玩家从地面起跳。左右碰到屏幕边缘会停住,掉出屏幕底部则扣一条命。

  二、Enemy 类 — 敌人
      敌人非常简单，就是一个自动来回走的物体。出生时记录初始位置作为左边界，
      向右走 patrol_range 格后掉头，回到初始位置再掉头。速度和方向都是固定的，
      没有 AI。玩家碰到敌人会扣命，但如果玩家从上方踩到敌人（下落时踩头），
      敌人会被消灭。

  三、Level 类 — 关卡
      每一关是一个完整的配置：平台的位置和宽度、敌人的出生点、金币和旗帜的位置。
      我用了硬编码的关卡数据，通过 buildLevel 函数根据关卡编号生成不同的布局。
      这样设计的好处是加新关卡只需要加一组坐标数据，不改任何逻辑。

  四、渲染系统 — render 函数
      我把终端当成一块 60 x 20 的像素画布。每帧先清屏，然后从后往前画：天空背景、
      平台、敌人、金币、旗帜，最后画玩家（确保玩家在最上层）。帧率控制在 30 FPS，
      用时间差来控制更新频率。

  五、输入系统 — get_key 函数
      终端的输入是个麻烦事。Windows 和 Linux/Mac 的底层 API 完全不同，
      所以我用 os.name 做了平台检测，分别用 msvcrt 和 termios 实现非阻塞按键读取。
      方向键在不同平台上返回的字节序列也不同，需要单独处理。

  这五个组件之间的配合方式是：main 函数每帧调用 get_key 获取输入，传给 Player，
  Player.update 计算新位置，Enemy.update 移动敌人，最后 render 画出整个画面。
  改关卡只改 Level，改手感只改 Player 的物理参数，改敌人行为只改 Enemy，
  互相完全独立。
================================================================================
"""

"""

"""




import os
import sys
import time
import random
import threading

# ============================================================================
#  检测操作系统，选输入方式
# ============================================================================
IS_WINDOWS = os.name == "nt"

if IS_WINDOWS:
    import msvcrt
else:
    import termios
    import tty
    import select

#定义按键逻辑,使用了mvcrt来做设计
def get_key():

    """非阻塞读取按键"""
    if IS_WINDOWS:
        if msvcrt.kbhit():
            key = msvcrt.getch()
            if key == b"\xe0" or key == b"\x00":  # 方向键前缀
                key = msvcrt.getch()
                if key == b"H": return "up"
                if key == b"P": return "down"
                if key == b"K": return "left"
                if key == b"M": return "right"
            try:
                return key.decode("utf-8").lower()
            except:
                return ""
        return ""
    else:
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            if select.select([sys.stdin], [], [], 0)[0]:
                ch = sys.stdin.read(1)
                if ch == "\x1b":
                    ch2 = sys.stdin.read(2)
                    if ch2 == "[A": return "up"
                    if ch2 == "[B": return "down"
                    if ch2 == "[C": return "right"
                    if ch2 == "[D": return "left"
                return ch.lower()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        return ""


# ============================================================================
#  游戏配置
# ============================================================================
WIDTH = 60
HEIGHT = 20
GRAVITY = 0.4
JUMP_VELOCITY = -1.8
PLAYER_SPEED = 1.0
ENEMY_SPEED = 0.5
FPS = 30

# ============================================================================
#  地图元素
# ============================================================================
#后续我加入了前端，这一部分后续将使用前端中ai生成的图片替换
PLAYER_CHAR = "@"
ENEMY_CHAR = "E"
COIN_CHAR = "$"
GROUND_CHAR = "="
PLATFORM_CHAR = "-"
FLAG_CHAR = "F"
EMPTY_CHAR = " "
SKY_CHAR = "."

#这里定义劫色移动方式（定义水平，竖直方向的动量，角色状态等基础信息）
class Player:
    def __init__(self, x, y):
        #定义水平竖直方向上的角色移动状态
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0           # 水平速度（x 分量）
        self.vy = 0.0           # 垂直速度（y 分量）
        self.move_dir = 0       # 当前输入的移动方向: -1 左, 0 无, 1 右
        self.on_ground = False
        self.score = 0
        self.lives = 3

    @property
    def velocity(self):
        """合并速度向量 (vx, vy)"""
        return (self.vx, self.vy)

    def update(self, platforms):
        # 水平速度 = 输入方向 * 速度系数（在空中也保留动量）
        self.vx = self.move_dir * PLAYER_SPEED
        # 垂直速度 = 上一帧 vy + 重力加速度
        self.vy += GRAVITY

        # 合并向量驱动位置变化
        self.x += self.vx
        self.y += self.vy

        # 碰撞检测
        self.on_ground = False
        for px, py, pw in platforms:
            if self._collides_platform(px, py, pw):
                if self.vy > 0:          # 下落中，踩到平台
                    self.y = py - 0.01
                    self.vy = 0
                    self.on_ground = True
                elif self.vy < 0:        # 上升中，撞到天花板
                    self.y = py + 1.01
                    self.vy = 0

        # 左右边界
        self.x = max(0, min(WIDTH - 1, self.x))

        # 掉落死亡
        if self.y > HEIGHT:
            self.lives -= 1
            self.x = 2
            self.y = HEIGHT - 5
            self.vy = 0

    def _collides_platform(self, px, py, pw):
        px1 = int(self.x)
        py1 = int(self.y)
        if py1 == py - 1 or py1 == py:
            if px1 >= px and px1 < px + pw:
                return True
        return False

    def jump(self):
        """跳跃：给垂直分量一个向上的初速度，与水平分量合并为斜抛运动"""
        if self.on_ground:
            self.vy = JUMP_VELOCITY   # 向上初速度（负 = 向上）
            self.on_ground = False
            # vx 保持当前移动方向，形成合并向量 (vx, vy)
            # 例: 按住 D 时跳跃 → 合并向量 (1.0, -1.8) → 右上方抛物线

    def move(self, direction):
        """设置移动方向，-1 左, 1 右"""
        self.move_dir = direction

    def stop(self):
        """松开方向键，水平速度归零"""
        self.move_dir = 0

#定义类别Enemy
class Enemy:
    def __init__(self, x, y, patrol_range=5):
        #逻辑和定义玩家一样，只不过行为固定
        self.x = float(x)
        self.y = float(y)
        self.direction = 1
        self.patrol_range = patrol_range
        self.start_x = x
        self.speed = ENEMY_SPEED

    #巡敌逻辑：在平台上左右移动
    def update(self):
        self.x += self.direction * self.speed
        if self.x > self.start_x + self.patrol_range:
            self.direction = -1
        elif self.x < self.start_x:
            self.direction = 1

#定义类Coin
class Coin:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.collected = False

#定义类Level(定义状态：得分，敌人数量等)
class Level:
    def __init__(self, level_num):
        self.num = level_num
        self.platforms = []    # [(x, y, width)]
        self.enemies = []
        self.coins = []
        self.flag_x = WIDTH - 3
        self.flag_y = 0
        self.generate()

    def generate(self):
        self.platforms = []
        self.enemies = []
        self.coins = []

        # 地面
        self.platforms.append((0, HEIGHT - 1, WIDTH))

        # 平台布局随关卡变化（增加数量，变化高度）
        #第一关
        if self.num == 1:
            platforms_config = [
                (10, HEIGHT - 5, 6),
                (20, HEIGHT - 7, 5),
                (30, HEIGHT - 5, 6),
                (40, HEIGHT - 7, 5),
                (50, HEIGHT - 5, 6),
            ]
            enemy_config = [(12, HEIGHT - 6), (32, HEIGHT - 6), (45, HEIGHT - 8)]
            coin_config = [(11, HEIGHT - 6), (13, HEIGHT - 6), (22, HEIGHT - 8),
                          (33, HEIGHT - 6), (42, HEIGHT - 8), (52, HEIGHT - 6)]
        #第二关
        elif self.num == 2:
            platforms_config = [
                (5, HEIGHT - 6, 4),
                (15, HEIGHT - 8, 4),
                (25, HEIGHT - 6, 4),
                (35, HEIGHT - 8, 4),
                (45, HEIGHT - 6, 8),
                (55, HEIGHT - 4, 4),
            ]
            enemy_config = [(8, HEIGHT - 7), (18, HEIGHT - 9), (30, HEIGHT - 7),
                          (40, HEIGHT - 9)]
            coin_config = [(7, HEIGHT - 7), (17, HEIGHT - 9), (28, HEIGHT - 7),
                          (38, HEIGHT - 9), (48, HEIGHT - 7), (56, HEIGHT - 5)]
        #第三关
        else:
            platforms_config = [
                (3, HEIGHT - 5, 5),
                (12, HEIGHT - 9, 4),
                (20, HEIGHT - 5, 4),
                (28, HEIGHT - 9, 5),
                (38, HEIGHT - 5, 4),
                (46, HEIGHT - 7, 4),
                (53, HEIGHT - 5, 7),
            ]
            enemy_config = [(5, HEIGHT - 6), (15, HEIGHT - 10), (23, HEIGHT - 6),
                          (32, HEIGHT - 10), (42, HEIGHT - 6), (50, HEIGHT - 8)]
            coin_config = [(5, HEIGHT - 6), (14, HEIGHT - 10), (22, HEIGHT - 6),
                          (30, HEIGHT - 10), (40, HEIGHT - 6), (48, HEIGHT - 8),
                          (55, HEIGHT - 6)]

        for x, y, w in platforms_config:
            self.platforms.append((x, y, w))

        for x, y in enemy_config:
            self.enemies.append(Enemy(x, y, random.randint(3, 6)))

        for x, y in coin_config:
            self.coins.append(Coin(x, y))

        # 旗子放最后一个平台上
        last_p = platforms_config[-1]
        self.flag_x = last_p[0] + last_p[2] - 2
        self.flag_y = last_p[1] - 3


# ============================================================================
#  渲染
# ============================================================================
def render(player, level, camera_x=0):
    """渲染一帧到终端"""
    screen = [[" "] * WIDTH for _ in range(HEIGHT)]

    # 天空装饰
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if random.random() < 0.02:
                screen[y][x] = "."

    # 平台
    for px, py, pw in level.platforms:
        for x in range(px, px + pw):
            if 0 <= x < WIDTH and 0 <= py < HEIGHT:
                screen[py][x] = GROUND_CHAR

    # 敌人
    for enemy in level.enemies:
        ex, ey = int(enemy.x), int(enemy.y)
        if 0 <= ex < WIDTH and 0 <= ey < HEIGHT:
            screen[ey][ex] = ENEMY_CHAR

    # 金币
    for coin in level.coins:
        if not coin.collected:
            cx, cy = coin.x, coin.y
            if 0 <= cx < WIDTH and 0 <= cy < HEIGHT:
                screen[cy][cx] = COIN_CHAR

    # 旗帜
    fx, fy = level.flag_x, level.flag_y
    if 0 <= fx < WIDTH and 0 <= fy < HEIGHT:
        screen[fy][fx] = FLAG_CHAR
        if fy + 1 < HEIGHT:
            screen[fy + 1][fx] = "|"
        if fy + 2 < HEIGHT:
            screen[fy + 2][fx] = "|"

    # 玩家
    px, py = int(player.x), int(player.y)
    if 0 <= px < WIDTH and 0 <= py < HEIGHT:
        screen[py][px] = PLAYER_CHAR

    # 输出
    os.system("cls" if IS_WINDOWS else "clear")
    border = "+" + "=" * WIDTH + "+"
    print(border)
    for row in screen:
        print("|" + "".join(row) + "|")
    print(border)
    print(f"  Lives: {player.lives}  Score: {player.score}  Level: {level.num}")
    print("  A/D: Move  W: Jump  Q: Quit")


# ============================================================================
#  主循环
# ============================================================================
def main():
    print("\n" * 5)
    print("=" * 50)
    print("    终端版超级马里奥 (Terminal Mario)")
    print("=" * 50)
    print()
    print("  收集硬币 $ 避开敌人 E 到达旗帜 F")
    print("  3 条命，共 3 关")
    print()
    print("  按 Enter 开始...")
    input()

    player = Player(2, HEIGHT - 2)
    current_level = 1
    level = Level(current_level)

    last_time = time.time()
    running = True

    while running and player.lives > 0:
        dt = time.time() - last_time
        if dt < 1.0 / FPS:
            time.sleep(1.0 / FPS - dt)
        dt = time.time() - last_time
        last_time = time.time()

        # 输入
        key = get_key()
        if key == "q":
            running = False
            break
        elif key == "a":
            player.move(-1)
        elif key == "d":
            player.move(1)
        elif key == "w":
            player.jump()
        else:
            player.stop()

        # 更新
        player.update(level.platforms)

        for enemy in level.enemies:
            enemy.update()

        # 碰撞检测
        px, py = int(player.x), int(player.y)

        # 金币碰撞
        for coin in level.coins:
            if not coin.collected and coin.x == px and abs(coin.y - py) <= 1:
                coin.collected = True
                player.score += 100

        # 敌人碰撞（碰到即死）
        for enemy in level.enemies:
            ex, ey = int(enemy.x), int(enemy.y)
            if abs(px - ex) <= 1 and abs(py - ey) <= 1:
                player.lives -= 1
                player.x = 2
                player.y = HEIGHT - 5
                player.vy = 0
                break

        # 到达旗帜
        if abs(px - level.flag_x) <= 1 and abs(py - level.flag_y) <= 2:
            player.score += 500
            current_level += 1
            if current_level > 3:
                render(player, level)
                print("\n" * 3)
                print("  恭喜通关！最终得分: " + str(player.score))
                print("  按 Enter 退出...")
                input()
                break
            else:
                level = Level(current_level)
                player.x = 2
                player.y = HEIGHT - 2
                player.vy = 0

        # 渲染
        render(player, level)

    if player.lives <= 0:
        print("\n  游戏结束！得分: " + str(player.score))
        input()


if __name__ == "__main__":
    main()
