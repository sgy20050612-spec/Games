import pathlib,subprocess,time,json,os,hashlib
root=pathlib.Path(__file__).resolve().parents[1];os.chdir(root)
status=root/'tools/build-status.json'
def write(state,**extra):status.write_text(json.dumps(dict(state=state,at=time.time(),**extra),indent=2))
def run(argv,log):
 with (root/'tools'/log).open('w') as out:
  r=subprocess.run(argv,stdout=out,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError(log+' failed: '+str(r.returncode))
try:
 write('importing')
 run(['tools/godot','--headless','--editor','--path','.', '--import','--quit'],'final-import.log')
 write('testing')
 run(['tools/godot','--headless','--path','.', '--script','scripts/verify.gd'],'final-verify.log')
 report=json.loads((root/'verification.json').read_text());assert not report['failures']
 write('waiting_for_web_templates',verification=report)
 target=pathlib.Path.home()/'.local/share/godot/export_templates/4.7.2.stable'
 deadline=time.monotonic()+1800
 while not (target/'web_release.zip').exists():
  if time.monotonic()>deadline:raise RuntimeError('Web templates unavailable after30minutes')
  time.sleep(2)
 (root/'build/web').mkdir(parents=True,exist_ok=True)
 write('exporting')
 run(['tools/godot','--headless','--path','.', '--export-release','Web','build/web/index.html'],'web-export.log')
 outputs={p.name:dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in (root/'build/web').iterdir() if p.is_file()}
 assert 'index.html' in outputs
 write('built',verification=report,files=outputs)
except Exception as e:
 write('failed',error=str(e));raise
