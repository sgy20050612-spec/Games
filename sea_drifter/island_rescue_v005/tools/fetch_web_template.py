"""Fetch just the nested web template from the official release with HTTP ranges."""
import urllib.request,struct,zlib,zipfile,hashlib,json
from pathlib import Path
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
def fetch(value):
 request=urllib.request.Request(URL,headers={'Range':'bytes='+value,'User-Agent':'Godot-local-development'})
 with urllib.request.urlopen(request,timeout=45) as r:
  if r.status!=206:raise RuntimeError('Server must support ranges; refusing full archive download')
  return r.read()
release=json.load(urllib.request.urlopen('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable',timeout=20))
size=next(a['size'] for a in release['assets'] if a['name']=='Godot_v4.7.2-stable_export_templates.tpz')
tail=fetch(f'{size-65536}-{size-1}')
pos=0;entry=None
while True:
 pos=tail.find(b'PK\x01\x02',pos)
 if pos<0:break
 fields=struct.unpack_from('<4s6H3I5H2I',tail,pos)
 name=tail[pos+46:pos+46+fields[10]]
 if name.endswith(b'/web_nothreads_release.zip'):
  entry=fields;break
 pos+=46+fields[10]+fields[11]+fields[12]
if entry is None:raise RuntimeError('No web template in central directory')
offset=entry[16]
header=fetch(f'{offset}-{offset+29}')
fields=struct.unpack('<4s5H3I2H',header)
start=offset+30+fields[9]+fields[10]
raw=fetch(f'{start}-{start+entry[8]-1}')
data=zlib.decompress(raw,-15) if entry[4]==8 else raw
if len(data)!=entry[9] or zlib.crc32(data)!=entry[7]:raise RuntimeError('Template ZIP entry CRC mismatch')
dest=Path(__file__).resolve().parents[2]/'游戏实时测试'/'templates'/'web_nothreads_release-official.zip'
dest.write_bytes(data)
with zipfile.ZipFile(dest) as z:
 if z.testzip():raise RuntimeError('Nested template CRC mismatch')
print(json.dumps({'path':str(dest),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()},ensure_ascii=False))
