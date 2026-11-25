from pathlib import Path
import subprocess,os,re,signal
root=Path.home()/'games/island-rescue';env=os.environ.copy();env['DISPLAY']=':1';env['XAUTHORITY']='/run/user/1002/gdm/Xauthority'
pidfile=root/'tools/coastal-live.pid'
if pidfile.exists():
 old=int(pidfile.read_text().strip())
 try:
  tree=subprocess.run(['xwininfo','-root','-tree'],env=env,capture_output=True,encoding='utf-8',timeout=8).stdout
  for line in tree.splitlines():
   if '水面与倒影预览' not in line:continue
   win=re.search(r'0x[0-9a-fA-F]+',line)
   if not win:continue
   value=subprocess.run(['xprop','-id',win.group(),'_NET_WM_PID'],env=env,capture_output=True,encoding='utf-8',timeout=5).stdout
   found=re.search(r'=\s*(\d+)',value)
   if found and int(found.group(1))==old:
    os.kill(old,signal.SIGTERM);print('Restarted only owned art-preview window',old)
 except (OSError,subprocess.TimeoutExpired,ValueError):pass
# A changed title means the user may have started a real game; keep that process.
env.pop('ISLAND_ART_LIVE',None)
with (root/'tools/v0-live.log').open('w') as out:
 p=subprocess.Popen([str(root/'tools/godot'),'--path',str(root),'--rendering-method','gl_compatibility'],env=env,cwd=root,stdin=subprocess.DEVNULL,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
(root/'tools/v0-live.pid').write_text(str(p.pid));print('Formal v0 PID',p.pid)
