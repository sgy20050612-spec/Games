import pathlib,json,urllib.request,zipfile,hashlib
root=pathlib.Path.home()/'games/island-rescue/tools';d=json.loads((root/'release.json').read_text())
a=next(a for a in d['assets'] if a['name'].endswith('_export_templates.tpz'))
p=root/a['name']
if not p.exists():urllib.request.urlretrieve(a['browser_download_url'],p)
h=hashlib.sha512(p.read_bytes()).hexdigest();assert any(l.split()[0]==h and p.name in l for l in (root/'SHA512-SUMS.txt').read_text().splitlines())
target=pathlib.Path.home()/'.local/share/godot/export_templates'/d['tag_name'].replace('-','.');target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(p) as z:
 for name in z.namelist():
  if name.rsplit('/',1)[-1].startswith('web_') or name.endswith('/version.txt'):
   dest=target/name.rsplit('/',1)[-1];dest.write_bytes(z.read(name))
print('Web templates verified',target,flush=True)
