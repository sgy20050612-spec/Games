# mod制作 (for repo) 

这两个 MOD 均由作者本人制作，使用 AI 辅助建模并将模型集成到游戏中。本目录集中展示作品和对应图片。

## 诅咒道具 — CursedCargo 0.2.5

![诅咒道具](images/cursed-cargo.png)

[下载 CursedCargo-0.2.5.zip](CursedCargo-0.2.5.zip)

## 大米任务 — RiceCommission 1.3.6

![大米任务](images/rice-commission.png)

[大米任务文件与合并脚本](RiceCommission/)

由于上传接口限制，原始 ZIP 分为 12 个二进制分片保存，合并后的内容与原文件完全一致。

1. 在仓库首页选择 **Code → Download ZIP** 并解压。
2. 打开本目录下的 RiceCommission 文件夹。
3. 在 PowerShell 中运行 `powershell -ExecutionPolicy Bypass -File .\Merge.ps1`。
4. 脚本将生成 `RiceCommission-1.3.6.zip` 并自动校验 SHA256。请勿单独解压分片。

原始 ZIP SHA256：`779c5e3dd705a8569d004a6cc3b368974e480751b66eb869581a4788b77c4d43`。

图片对应关系：图一为诅咒道具；图二为大米任务。
