from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
dest=root.parent/'交付'/'海岛拯救_v0.0.5_Windows完整包_2026-11-24.zip'
engine=root.parent/'Godot'/'Godot_v4.7.2-stable_win64.exe'
entries=[]
for p in sorted(root.rglob('*')):
 if not p.is_file():continue
 rel=p.relative_to(root)
 if any(x in {'.godot','.git','__pycache__','build'} for x in rel.parts):continue
 if p.name.endswith(('.tar.gz','.zip','.log','.import')):continue
 if rel.parts[0]=='tools' and p.suffix!='.py':continue
 entries.append((p,'Game/'+rel.as_posix()))
entries.append((engine,'Runtime/Godot.exe'))
entries.append((root.parent/'Godot'/'GODOT-LICENSE.txt','Runtime/GODOT-LICENSE.txt'))
launch=b'@echo off\r\ncd /d "%~dp0"\r\necho Preparing game assets. Please wait...\r\nstart /wait "" "%~dp0Runtime\\Godot.exe" --headless --editor --path "%~dp0Game" --import --quit\r\nif errorlevel 1 (\r\n echo Asset import failed. Please keep this window for diagnosis.\r\n pause\r\n exit /b 1\r\n)\r\nstart "" "%~dp0Runtime\\Godot.exe" --path "%~dp0Game"\r\n'
readme='''海岛～拯救！ v0.0.5 Windows完整包（2026-11-24）

完整解压后双击“启动游戏.cmd”。首次启动会导入素材，无需安装Python或Godot。
修改工程请双击“编辑工程.cmd”。适用Windows10/11 64位、OpenGL3.3。

操作：WASD移动，E交互/工匠作坊/迫击炮，按住E采集，I物品栏，B建造，左键攻击，右键交付手持装备，F回血，U升级核心，Tab菜单。
本包包含当前全部工程源码、素材（含历史备份）、设计文档、提示词、预览、测试脚本和报告、Godot运行环境，以及当前Web构建。
最新规则与完成情况见 Game/变更说明_v0.0.5_岗位与物品栏.md。历史报告仅代表对应版本，不代表最新规则全部验收。
尚待继续：资源点碰撞、首页绳子动画、完整十夜平衡及外部试玩。
不含用户存档、连接密钥、构建缓存和旧传输压缩包。存档仍保存在运行电脑用户目录，换电脑不会自动迁移。
Web目录为浏览器构建，需要通过HTTP服务器打开game.html；Windows直接使用启动游戏.cmd。
引擎与字体授权分别见Runtime和Game/assets/licenses。
'''.encode('utf-8-sig')
web=root.parent/'游戏实时测试'/'www'
for p in sorted(web.glob('game.*')):
 if p.is_file():entries.append((p,'Web/'+p.name))
dest.parent.mkdir(parents=True,exist_ok=True)
manifest=[]
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p,name in entries:
  z.write(p,'海岛拯救_v0/'+name)
  manifest.append({'path':name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 for name,data in [('启动游戏.cmd',launch),('编辑工程.cmd',b'@echo off\r\nstart "" "%~dp0Runtime\\Godot.exe" --editor --path "%~dp0Game"\r\n'),('先读我.txt',readme)]:
  z.writestr('海岛拯救_v0/'+name,data)
  manifest.append({'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 z.writestr('海岛拯救_v0/文件清单_SHA256.json',json.dumps(manifest,ensure_ascii=False,indent=2))
with zipfile.ZipFile(dest) as z:
 bad=z.testzip()
 if bad:raise RuntimeError('CRC failure: '+bad)
 assert z.read('海岛拯救_v0/Runtime/Godot.exe')==engine.read_bytes()
digest=hashlib.sha256(dest.read_bytes()).hexdigest()
dest.with_suffix('.zip.sha256').write_text(digest+'  '+dest.name+'\n',encoding='utf-8')
print(json.dumps({'path':str(dest),'bytes':dest.stat().st_size,'files':len(manifest)+1,'sha256':digest,'crc':'passed'},ensure_ascii=False))
