
"""
================================================================================
  游戏规则 — 恶魔轮盘赌 (Buckshot Roulette)(写在这里便于代码编写参考)
================================================================================

【1. 角色】
  - 玩家 (🧑)：你，人类操作，自主决策
  - 庄家 (🎭)：AI 对手，由 ai_decide() 函数控制
  - 双方初始各有 3 条命，先归零的一方输掉该回合

【2. 组件（道具）】
  每回合开始，双方各随机获得 2~4 个道具。
  道具由 random.choices() 从全部类型中随机抽取，可能重复。

  道具清单：
    A. 放大镜 🔍  — 查看当前弹膛是实弹还是空弹
    B. 啤酒   🍺  — 退出当前子弹（跳过这一发）
    C. 手铐   ⛓️  — 对手跳过下一回合
    D. 香烟   🚬  — 恢复 1 点生命值（上限 3）
    E. 锯子   🪚  — 下一发实弹造成 2 倍伤害
    F. 逆变器 🔄  — 翻转当前弹种（实弹 <-> 空弹）

【3. 规则逻辑】
  一、开局阶段
      a. 装弹：根据当前回合配置，随机生成实弹和空弹的排列
      b. 发道具：双方各获得 2~4 个随机道具
      c. 随机决定谁先手

  二、回合循环（直到回合结束）
      当前方每轮可选择：
        A. 向对手开枪
           实弹 : 扣对手血，换对手行动
           空弹 : 无事发生，换对手行动
        B. 向自己开枪
           实弹 : 扣自己血，换对手行动
           空弹 : 无事发生，自己继续行动
        C. 使用道具（不消耗行动机会，用完后仍可选择 A 或 B）

  三、回合结束条件
      a. 一方生命归零 : 对方赢得本回合
      b. 弹膛打空 : 平局，进入下一回合

  四、赌局结束
      3 回合全部结束后，生命多的一方获胜。
================================================================================


【整体设计框架】

  这个游戏虽然简单，但我把它拆成了三个独立的模块，各司其职：

  一、GameState 类 — 数据中心
      这个类不负责任何"决策"，只负责"记住当前状态"。
      所有游戏数据都在里面：弹膛里有什么子弹、双方血量、谁有什么道具。
      所有规则操作也在里面：开枪(fire)、用道具(use_item)、判定回合结束(check_round_end)。
      AI 和玩家调用同一套方法，谁都不能"作弊"。

  二、AI 决策引擎 — ai_decide() 函数
      输入当前 GameState，输出一个行动字符串。
      决策逻辑很简单：先看有没有道具能用，再看当前是实弹还是空弹，
      实弹打对手，空弹赌运气。和玩家用的是同一套 fire() 和 use_item()。

  三、主循环 — main() 函数
      终端交互部分：清屏 → 显示状态 → 等待玩家输入 → 执行操作 → 庄家回合 → 循环。
      玩家操作分三种：开枪打庄家、开枪打自己、使用道具。
      庄家回合是自动的，dealer_turn() 循环直到回合切换。

  三个模块的配合：main() 只负责"显示和输入"，GameState 负责"数据和规则"，
  ai_decide() 负责"庄家大脑"。改规则只改 GameState，改 AI 只改 ai_decide，
  改界面只改 main()，互不影响。



"""

import random
import os
import time

# ============================================================================
#  配置
#  我在这里定义了所有游戏常量，修改这些数值就能调整游戏难度和节奏。
#  MAX_LIVES 控制容错率，TOTAL_ROUNDS 控制游戏长度。
# ============================================================================
MAX_LIVES = 3
TOTAL_ROUNDS = 3

# 我设计了三轮递进的难度：第1轮4发子弹简单上手，第2轮6发增加变数，
# 第3轮8发让运气和策略都达到顶峰。每轮的道具数量也同步增加。
ROUND_CONFIG = [
    {"total_shells": 4, "live_min": 1, "live_max": 2, "items": 2},
    {"total_shells": 6, "live_min": 2, "live_max": 3, "items": 3},
    {"total_shells": 8, "live_min": 3, "live_max": 5, "items": 4},
]

ITEMS = {
    "magnifier": {"name": "放大镜", "icon": "O", "desc": "查看当前子弹"},
    "beer":      {"name": "啤酒",   "icon": "U", "desc": "退出当前子弹"},
    "cuffs":     {"name": "手铐",   "icon": "C", "desc": "对手跳过下回合"},
    "cigarette": {"name": "香烟",   "icon": "S", "desc": "恢复1点生命"},
    "saw":       {"name": "锯子",   "icon": "W", "desc": "实弹双倍伤害"},
    "inverter":  {"name": "逆变器", "icon": "I", "desc": "翻转当前弹种"},
}

ALL_ITEMS = list(ITEMS.keys())


# ============================================================================
#  游戏状态
# ============================================================================
class GameState:
    # --- 初始化：创建一场全新的游戏，所有数值归零，等待 start_new_round() 激活 ---
    def __init__(self):
        self.round = 0
        self.player_lives = MAX_LIVES
        self.dealer_lives = MAX_LIVES
        self.round_active = False
        self.game_over = False
        self.shells = []
        self.current_shell_idx = 0
        self.player_items = []
        self.dealer_items = []
        self.player_turn = True
        self.player_cuffed = False
        self.dealer_cuffed = False
        self.player_saw = False
        self.dealer_saw = False
        self.magnifier_used = False
        self.round_history = []

    # --- 开始新回合：根据当前回合数装弹、发道具、随机决定先手 ---
    def start_new_round(self):
        cfg = ROUND_CONFIG[self.round]
        total = cfg["total_shells"]
        live = random.randint(cfg["live_min"], cfg["live_max"])
        blank = total - live
        self.shells = (["live"] * live) + (["blank"] * blank)
        random.shuffle(self.shells)
        self.current_shell_idx = 0

        pool = random.choices(ALL_ITEMS, k=cfg["items"] * 2)
        self.player_items = pool[:cfg["items"]]
        self.dealer_items = pool[cfg["items"]:]

        self.player_cuffed = False
        self.dealer_cuffed = False
        self.player_saw = False
        self.dealer_saw = False
        self.magnifier_used = False
        self.round_active = True
        self.player_turn = True  # 玩家永远先手，避免开局被庄家偷袭

    # --- 开火：取出当前子弹，判定实弹/空弹，扣血，返回结果 ---
    def fire(self, target_is_dealer):
        if self.current_shell_idx >= len(self.shells):
            return {"hit": False, "is_live": False, "damage": 0}
        shell = self.shells[self.current_shell_idx]
        is_live = (shell == "live")
        self.current_shell_idx += 1

        if is_live:
            if target_is_dealer:
                damage = 2 if self.player_saw else 1
                self.player_saw = False
                self.dealer_lives = max(0, self.dealer_lives - damage)
            else:
                damage = 2 if self.dealer_saw else 1
                self.dealer_saw = False
                self.player_lives = max(0, self.player_lives - damage)
        else:
            damage = 0
        self.magnifier_used = False
        return {"hit": is_live, "is_live": is_live, "damage": damage}

    # --- 使用道具：检查合法性，执行道具效果，从背包移除 ---
    def use_item(self, item_id):
        if item_id not in self.player_items:
            return "你没有这个道具"
        if item_id == "magnifier":
            if self.current_shell_idx >= len(self.shells):
                return "弹膛已空"
            s = self.shells[self.current_shell_idx]
            self.magnifier_used = True
            self.player_items.remove("magnifier")
            return f"当前子弹: {'!! 实弹 !!' if s == 'live' else '空弹 (安全)'}"
        elif item_id == "beer":
            if self.current_shell_idx >= len(self.shells):
                return "弹膛已空"
            self.shells.pop(self.current_shell_idx)
            self.player_items.remove("beer")
            return "退出一颗子弹"
        elif item_id == "cuffs":
            if self.dealer_cuffed:
                return "庄家已被铐"
            self.dealer_cuffed = True
            self.player_items.remove("cuffs")
            return "庄家下回合跳过"
        elif item_id == "cigarette":
            if self.player_lives >= MAX_LIVES:
                return "生命已满"
            self.player_lives = min(MAX_LIVES, self.player_lives + 1)
            self.player_items.remove("cigarette")
            return f"恢复1点生命 (当前: {self.player_lives})"
        elif item_id == "saw":
            self.player_saw = True
            self.player_items.remove("saw")
            return "锯刃已激活"
        elif item_id == "inverter":
            if self.current_shell_idx >= len(self.shells):
                return "弹膛已空"
            s = self.shells[self.current_shell_idx]
            self.shells[self.current_shell_idx] = "blank" if s == "live" else "live"
            self.player_items.remove("inverter")
            return "已翻转"
        return "?"

    # --- 判定回合结束：有人倒下、弹膛打空则结束当前回合 ---
    def check_round_end(self):
        if self.player_lives <= 0:
            self.round_history.append("loss")
            self._end_round("dealer")
            return True
        if self.dealer_lives <= 0:
            self.round_history.append("win")
            self._end_round("player")
            return True
        if self.current_shell_idx >= len(self.shells):
            self._end_round(None)
            return True
        return False

    # --- 内部方法：回合结束后的收尾工作，推进回合数或结束游戏 ---
    def _end_round(self, winner):
        self.round_active = False
        if winner is not None:
            self.round += 1
            if self.round >= TOTAL_ROUNDS:
                self.game_over = True
                if self.player_lives > self.dealer_lives:
                    self.winner = "player"
                elif self.dealer_lives > self.player_lives:
                    self.winner = "dealer"
                else:
                    self.winner = "draw"


# ============================================================================
#  AI 决策
# ============================================================================
# --- 庄家 AI：读取当前状态，决定用道具、打玩家还是打自己 ---
def ai_decide(state):
    live = state.shells.count("live")
    blank = state.shells.count("blank")
    total = len(state.shells)
    if total == 0 or state.current_shell_idx >= total:
        return "shoot_player"
    cur = state.shells[state.current_shell_idx]
    is_live = (cur == "live")
    ratio = live / total if total > 0 else 0

    # 道具优先
    if "magnifier" in state.dealer_items and not state.magnifier_used:
        return "use_item:magnifier"
    if "cuffs" in state.dealer_items and not state.player_cuffed:
        return "use_item:cuffs"
    if "saw" in state.dealer_items and is_live and not state.dealer_saw:
        return "use_item:saw"
    if "cigarette" in state.dealer_items and state.dealer_lives <= 1:
        return "use_item:cigarette"
    if "inverter" in state.dealer_items and not is_live and live > blank:
        return "use_item:inverter"
    if "beer" in state.dealer_items and is_live:
        return "use_item:beer"

    # 决策
    if is_live:
        return "shoot_player"
    else:
        if ratio > 0.5 and state.dealer_lives >= 3:
            return "shoot_self"
        return "shoot_player"


# ============================================================================
#  终端 UI（AI辅助）
# ============================================================================
# --- 清屏：Windows 用 cls，其他系统用 clear ---
def clear():
    os.system("cls" if os.name == "nt" else "clear")


# --- 绘制血条：+ 表示有生命，- 表示已损失 ---
def hearts(n, max_n=MAX_LIVES):
    return " ".join(["+" if i < n else "-" for i in range(max_n)])


# --- 终端 UI：清屏后打印当前回合、血量、弹膛、道具、操作提示 ---
def show_state(state):
    clear()
    print("=" * 50)
    print(f"  回合 {state.round + 1}/{TOTAL_ROUNDS}    ", end="")
    for i in range(TOTAL_ROUNDS):
        if i < len(state.round_history):
            print("O" if state.round_history[i] == "win" else "X", end=" ")
        elif i == state.round:
            print("*", end=" ")
        else:
            print(".", end=" ")
    print()
    print("=" * 50)
    print(f"  你:   {hearts(state.player_lives)}  {'[锯]' if state.player_saw else ''} {'[铐]' if state.player_cuffed else ''}")
    print(f"  庄家: {hearts(state.dealer_lives)}  {'[锯]' if state.dealer_saw else ''} {'[铐]' if state.dealer_cuffed else ''}")
    print()

    # 弹膛
    live_c = state.shells.count("live")
    blank_c = state.shells.count("blank")
    print(f"  弹膛: {live_c}实弹 + {blank_c}空弹 (共{len(state.shells)}发)")
    dots = ""
    for i in range(len(state.shells)):
        if i < state.current_shell_idx:
            dots += "· "
        else:
            dots += "? "
    print("  [{}]".format(dots))
    if state.current_shell_idx < len(state.shells):
        print(f"  当前第 {state.current_shell_idx + 1} 发")
    else:
        print(f"  弹膛已空")
    print()

    # 道具
    if state.player_items:
        print("  你的道具:")
        for idx, item_id in enumerate(state.player_items):
            info = ITEMS[item_id]
            print(f"    [{idx + 1}] {info['name']} {info['icon']} - {info['desc']}")
    else:
        print("  你的道具: (无)")
    print(f"  庄家道具: {len(state.dealer_items)}个")
    print()

    # 回合状态
    if not state.round_active:
        if state.game_over:
            print("  === 游戏结束 ===")
        else:
            print("  回合结束，按 Enter 继续...")
    elif state.player_turn:
        print("  >>> 你的回合 <<<")
    else:
        print("  庄家正在思考...")


# --- 玩家回合：显示状态，等待输入，执行开枪或使用道具 ---
def player_turn(state):
    while state.player_turn and state.round_active:
        show_state(state)
        print("  操作: [1]向庄家开枪  [2]向自己开枪  [3]使用道具")
        choice = input("  > ").strip()

        if choice == "1":
            result = state.fire(target_is_dealer=True)
            target = "庄家"
            if result["is_live"]:
                print(f"\n  !! 实弹 !! {target}受到 {result['damage']} 点伤害！")
            else:
                print(f"\n  空弹。无事发生。")
            input("  按 Enter 继续...")
            if state.check_round_end():
                return
            state.player_turn = False

        elif choice == "2":
            result = state.fire(target_is_dealer=False)
            if result["is_live"]:
                print(f"\n  !! 实弹 !! 你受到 {result['damage']} 点伤害！")
            else:
                print(f"\n  空弹。你继续行动。")
            input("  按 Enter 继续...")
            if state.check_round_end():
                return
            if result["is_live"]:
                state.player_turn = False

        elif choice == "3":
            if not state.player_items:
                print("  没有道具可用")
                input("  按 Enter 继续...")
                continue
            show_state(state)
            print("  选道具 (输入编号, 0返回):")
            for idx, item_id in enumerate(state.player_items):
                print(f"    [{idx + 1}] {ITEMS[item_id]['name']}")
            c = input("  > ").strip()
            if c == "0":
                continue
            try:
                idx = int(c) - 1
                if 0 <= idx < len(state.player_items):
                    item_id = state.player_items[idx]
                    msg = state.use_item(item_id)
                    print(f"\n  {msg}")
                    input("  按 Enter 继续...")
                else:
                    print("  无效选择")
                    input("  按 Enter 继续...")
            except ValueError:
                print("  无效输入")
                input("  按 Enter 继续...")
        else:
            print("  无效选择")
            input("  按 Enter 继续...")


# --- 庄家回合：AI 自动决策并执行，循环直到回合切换或有结果 ---
def dealer_turn(state):
    """庄家自动行动"""
    moves = 0
    max_moves = 10
    while not state.player_turn and state.round_active and moves < max_moves:
        moves += 1
        decision = ai_decide(state)

        if decision.startswith("use_item:"):
            item_id = decision.split(":")[1]
            if item_id in state.dealer_items:
                state.dealer_items.remove(item_id)
                info = ITEMS[item_id]
                print(f"\n  庄家使用: {info['name']}")

                if item_id == "magnifier":
                    state.magnifier_used = True
                elif item_id == "cuffs":
                    state.player_cuffed = True
                elif item_id == "cigarette":
                    state.dealer_lives = min(MAX_LIVES, state.dealer_lives + 1)
                elif item_id == "saw":
                    state.dealer_saw = True
                elif item_id == "inverter":
                    if state.current_shell_idx < len(state.shells):
                        cur = state.shells[state.current_shell_idx]
                        state.shells[state.current_shell_idx] = "blank" if cur == "live" else "live"
                elif item_id == "beer":
                    if state.current_shell_idx < len(state.shells):
                        state.shells.pop(state.current_shell_idx)
            continue

        elif decision == "shoot_player":
            print(f"\n  庄家向你开枪！")
            result = state.fire(target_is_dealer=False)
            if result["is_live"]:
                print(f"  !! 实弹 !! 你受到 {result['damage']} 点伤害！")
            else:
                print(f"  空弹。")
            if state.check_round_end():
                return
            if result["is_live"]:
                state.player_turn = True
                # 手铐检查
                if state.player_cuffed:
                    state.player_cuffed = False
                    print(f"  你被手铐铐住，回合跳过！")
                    state.player_turn = False
                    continue
                return
            continue

        elif decision == "shoot_self":
            print(f"\n  庄家向自己开枪！")
            result = state.fire(target_is_dealer=True)
            if result["is_live"]:
                print(f"  !! 实弹 !! 庄家受到 {result['damage']} 点伤害！")
            else:
                print(f"  空弹。")
            if state.check_round_end():
                return
            if result["is_live"]:
                state.player_turn = True
                if state.player_cuffed:
                    state.player_cuffed = False
                    print(f"  你被手铐铐住，回合跳过！")
                    state.player_turn = False
                    continue
                return
            continue

    # 兜底：如果循环正常退出（非 return），强制交还回合
    if state.round_active and not state.player_turn:
        state.player_turn = True


# ============================================================================
#  主循环
#  我在这里组织了整个游戏的运转：标题画面 -> 开始游戏 -> 玩家回合/庄家回合交替 -> 结束。
#  所有交互通过 input() 完成，不需要鼠标，纯键盘操作。
# ============================================================================
# ============================================================================
# --- 主循环：显示标题 → 开始游戏 → 回合循环（玩家/庄家交替）→ 结束 ---
def main():
    state = GameState()

    while True:
        clear()
        print("=" * 50)
        print("       恶魔轮盘赌 (Buckshot Roulette)")
        print("       终端版")
        print("=" * 50)
        print()
        print("  一把霰弹枪，随机实弹与空弹。")
        print("  3回合，3条命。活到最后!")
        print()
        print("  [1] 开始游戏")
        print("  [2] 退出")
        choice = input("  > ").strip()

        if choice == "2":
            print("  再见!")
            break
        elif choice != "1":
            continue

        # 开始新游戏
        state = GameState()
        state.start_new_round()
        _run_dealer_first(state)

        # 回合循环
        while not state.game_over:
            if not state.round_active:
                show_state(state)
                input()
                state.start_new_round()
                _run_dealer_first(state)
                continue

            if state.player_turn:
                player_turn(state)
            else:
                show_state(state)
                dealer_turn(state)

        # 游戏结束
        show_state(state)
        if state.winner == "player":
            print("\n  !! 你赢了 !!")
        elif state.winner == "dealer":
            print("\n  庄家赢了...")
        else:
            print("\n  平局!")
        print()
        print("  按 Enter 继续...")
        input()


# --- 庄家先手处理：新回合开始若庄家先手，自动执行；秒结束则递归推进 ---
def _run_dealer_first(state):
    """如果庄家先手，自动执行"""
    if state.round_active and not state.player_turn:
        dealer_turn(state)
    # 秒结束自动推进
    while not state.round_active and not state.game_over:
        state.start_new_round()
        if state.round_active and not state.player_turn:
            dealer_turn(state)


if __name__ == "__main__":
    main()
