from pathlib import Path
import os,json,zipfile,subprocess,time,hashlib,traceback
root=Path(__file__).resolve().parents[1];os.chdir(root)
status=root/'tools/v0-release-status.json'
def state(name,**extra):status.write_text(json.dumps(dict(state=name,at=time.time(),**extra),indent=2))
def run(args,filename,env=None):
 with (root/'tools'/filename).open('w') as out:
  result=subprocess.run(args,stdout=out,stderr=subprocess.STDOUT,env=env)
 if result.returncode:raise RuntimeError(filename+' exit '+str(result.returncode))
try:
 state('installing_windows_template')
 template_dir=Path.home()/'.local/share/godot/export_templates/4.7.2.stable';template_dir.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(next((root/'tools').glob('*export_templates.tpz'))) as z:
  for name in ['windows_release_x86_64.exe','windows_release_x86_64_console.exe']:
   item=next(x for x in z.namelist() if x.rsplit('/',1)[-1]==name)
   target=template_dir/name
   if not target.exists():target.write_bytes(z.read(item))
 state('importing')
 run(['tools/godot','--headless','--editor','--path','.', '--import','--quit'],'v0-import.log')
 state('testing')
 run(['tools/godot','--headless','--path','.', '--script','scripts/verify.gd'],'v0-verify.log')
 env=os.environ.copy();env['DISPLAY']=':1';env['XAUTHORITY']='/run/user/1002/gdm/Xauthority'
 run(['tools/godot','--path','.', '--script','scripts/ui_verify.gd','--rendering-method','gl_compatibility'],'v0-ui.log',env)
 run(['tools/godot','--path','.', '--script','scripts/water_verify.gd','--rendering-method','gl_compatibility'],'v0-water.log',env)
 for target in ['web','windows']:(root/'build'/target).mkdir(parents=True,exist_ok=True)
 state('exporting_web')
 run(['tools/godot','--headless','--path','.', '--export-release','Web','build/web/index.html'],'v0-web.log')
 state('exporting_windows')
 run(['tools/godot','--headless','--path','.', '--export-release','Windows','build/windows/IslandRescue_v0.exe'],'v0-windows.log')
 reports={name:json.loads((root/name).read_text()) for name in ['verification.json','ui-verification.json','water-verification.json']}
 assert all(not r.get('failures') for r in reports.values())
 outputs={str(p.relative_to(root)):dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in (root/'build').rglob('*') if p.is_file() and not p.name.endswith('.import')}
 state('built',reports=reports,files=outputs)
except Exception as e:state('failed',error=str(e),trace=traceback.format_exc());raise
