"""Local-only Godot development build/watch server. No external publishing."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import json,subprocess,threading,time,shutil,os,zipfile
SOURCE=Path(__file__).resolve().parents[1]
BASE=SOURCE.parent/'游戏实时测试'
PROJECT=BASE/'project';WWW=BASE/'www';WWW.mkdir(parents=True,exist_ok=True)
GODOT=SOURCE.parent/'Godot'/'Godot_v4.7.2-stable_win64.exe'
TEMPLATE=BASE/'templates'/'web_nothreads_release-official.zip'
STATE={'building':False,'waiting':True,'generation':0,'error':'','updated':0}
RUNTIME=[]
LOCK=threading.Lock();REQUEST=threading.Event()
HTML='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>海岛拯救 · 联调</title>
<style>*{box-sizing:border-box}body{margin:0;background:#182327;color:#ece1c4;font:14px system-ui}header{display:flex;gap:8px;align-items:center;padding:10px;background:#352b21;flex-wrap:wrap}button{background:#c8b181;color:#29241b;border:0;border-radius:4px;padding:7px 12px;cursor:pointer}small{display:block;padding:7px;color:#bbc8bc}iframe{border:0;width:100%;height:calc(100vh - 114px);background:#000}#error{white-space:pre-wrap;color:#ffb4a7;padding:8px;max-height:180px;overflow:auto;display:none}</style>
<header><b>海岛～拯救！</b><span id="state">正在准备游戏…</span><button onclick="reloadGame()" id="reload" disabled>载入最新版本</button><button onclick="fetch('/build',{method:'POST'})">重新构建</button><button onclick="document.getElementById('game').requestFullscreen()">游戏全屏</button></header>
<small>源码修改后自动构建。更新就绪时点击载入；重新载入会重启游戏，请先在白天存档。</small><div id="error"></div><iframe id="game" allow="autoplay; fullscreen; gamepad" tabindex="0"></iframe>
<script>let shown=0,latest=0;function reloadGame(){if(!latest)return;document.getElementById('game').src='/game.html?v='+latest;shown=latest;document.getElementById('game').focus()}
async function poll(){try{let s=await(await fetch('/status',{cache:'no-store'})).json();latest=s.generation;let pending=latest>shown;document.getElementById('reload').disabled=!latest||s.building;document.getElementById('state').textContent=s.waiting?'正在准备运行组件…':s.building?'正在构建…':s.error?'构建失败，保留上一版':pending?'新版本已就绪':'当前版本 '+shown;let e=document.getElementById('error');e.textContent=s.error;e.style.display=s.error?'block':'none';if(latest&&!shown&&!s.building)reloadGame()}catch(e){document.getElementById('state').textContent='本地服务未连接'}setTimeout(poll,1200)}poll()</script></html>'''
(WWW/'index.html').write_text(HTML,encoding='utf-8')
def source_files():
 for folder in ['assets','data','scripts']:
  for p in (SOURCE/folder).rglob('*'):
   if p.is_file() and p.suffix not in ['.import','.log']:yield p
 for name in ['project.godot','main.tscn','export_presets.cfg']:yield SOURCE/name
def signature():return tuple((str(p),p.stat().st_mtime_ns,p.stat().st_size) for p in sorted(source_files()))
def build():
 with LOCK:STATE.update(building=True,error='')
 try:
  if not TEMPLATE.exists():raise RuntimeError('Web导出模板尚未下载完成')
  PROJECT.mkdir(parents=True,exist_ok=True)
  for p in source_files():
   target=PROJECT/p.relative_to(SOURCE);target.parent.mkdir(parents=True,exist_ok=True)
   shutil.copy2(p,target)
  config=(PROJECT/'export_presets.cfg').read_text(encoding='utf-8')
  config=config.replace('custom_template/release=""','custom_template/release="'+TEMPLATE.as_posix()+'"',1)
  (PROJECT/'export_presets.cfg').write_text(config,encoding='utf-8')
  with (BASE/'build.log').open('w',encoding='utf-8') as log:
   for args in [['--headless','--editor','--path',str(PROJECT),'--import','--quit'],['--headless','--path',str(PROJECT),'--export-release','Web',str(WWW/'game.html')]]:
    r=subprocess.run([str(GODOT),*args],stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    if r.returncode:raise RuntimeError((BASE/'build.log').read_text(encoding='utf-8',errors='replace')[-5000:])
  page=WWW/'game.html'
  hook='''<script>(()=>{const report=(kind,args)=>{fetch('/runtime-log',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({kind,message:Array.from(args).map(String).join(' '),at:Date.now()})}).catch(()=>{})};const old=console.error;console.error=function(...args){report('console-error',args);old.apply(console,args)};window.addEventListener('error',e=>report('error',[e.message,e.filename,e.lineno]));window.addEventListener('unhandledrejection',e=>report('promise',[e.reason]));})();</script>'''
  text=page.read_text(encoding='utf-8');page.write_text(text.replace('</head>',hook+'</head>'),encoding='utf-8')
  with LOCK:STATE.update(generation=int(time.time()*1000),updated=time.time())
 except Exception as e:
  with LOCK:STATE['error']=str(e)
 finally:
  with LOCK:STATE['building']=False
def watch():
 old=None
 while True:
  if not TEMPLATE.exists() or not zipfile.is_zipfile(TEMPLATE):
   with LOCK:STATE['waiting']=True
   time.sleep(1);continue
  with LOCK:STATE['waiting']=False
  current=signature()
  if old!=current or REQUEST.is_set():
   time.sleep(1)
   old=signature();REQUEST.clear();build()
  time.sleep(1)
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(WWW),**kw)
 def end_headers(self):
  self.send_header('Cache-Control','no-store');super().end_headers()
 def do_GET(self):
  if self.path=='/runtime-log':
   with LOCK:data=json.dumps(RUNTIME,ensure_ascii=False).encode()
   self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.end_headers();self.wfile.write(data);return
  if self.path=='/status':
   with LOCK:data=json.dumps(STATE,ensure_ascii=False).encode()
   self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
  else:super().do_GET()
 def do_POST(self):
  if self.path=='/runtime-log':
   try:
    length=min(int(self.headers.get('Content-Length','0')),16384)
    record=json.loads(self.rfile.read(length));record={'kind':str(record.get('kind',''))[:80],'message':str(record.get('message',''))[:10000],'at':record.get('at')}
    with LOCK:RUNTIME.append(record);RUNTIME[:]=RUNTIME[-100:]
    with (BASE/'runtime-errors.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(record,ensure_ascii=False)+'\n')
    self.send_response(204);self.end_headers()
   except Exception:self.send_error(400)
   return
  if self.path!='/build':self.send_error(404);return
  REQUEST.set();self.send_response(202);self.end_headers()
 def log_message(self,*a):pass
if __name__=='__main__':
 threading.Thread(target=watch,daemon=True).start()
 print('http://127.0.0.1:8878/',flush=True)
 ThreadingHTTPServer(('127.0.0.1',8878),Handler).serve_forever()
