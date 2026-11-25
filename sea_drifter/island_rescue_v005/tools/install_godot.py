import pathlib,json,urllib.request,hashlib,zipfile
root=pathlib.Path.home()/'games/island-rescue/tools'
d=json.loads((root/'release.json').read_text())
for name in ['SHA512-SUMS.txt',next(a['name'] for a in d['assets'] if a['name'].endswith('linux.x86_64.zip'))]:
 a=next(a for a in d['assets'] if a['name']==name);out=root/name
 if not out.exists():urllib.request.urlretrieve(a['browser_download_url'],out)
z=next(root.glob('*linux.x86_64.zip'));h=hashlib.sha512(z.read_bytes()).hexdigest()
assert any(line.split()[0]==h and z.name in line for line in (root/'SHA512-SUMS.txt').read_text().splitlines()),'HASH MISMATCH'
with zipfile.ZipFile(z) as f:f.extractall(root)
binary=next(p for p in root.glob('Godot*linux.x86_64') if p.is_file());binary.chmod(0o755)
link=root/'godot'
if not link.exists():link.symlink_to(binary.name)
print('Verified Godot',binary,flush=True)
