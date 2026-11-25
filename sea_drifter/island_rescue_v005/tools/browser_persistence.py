from pathlib import Path
import json,time
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.action_chains import ActionChains
root=Path(__file__).resolve().parents[1]
o=Options();o.binary_location='/snap/firefox/current/usr/lib/firefox/firefox'
o.set_preference('webgl.force-enabled',True)
d=webdriver.Firefox(options=o)
report={'scope':'Firefox same-profile refresh and automatic-slot persistence; not long-term or cross-browser acceptance'}
try:
 d.set_window_size(1280,800)
 def click(x,y):
  b=d.execute_script('const r=document.getElementById("canvas").getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}')
  s=min(b['w']/1152,b['h']/648)
  px=b['x']+(b['w']-1152*s)/2+x*s;py=b['y']+(b['h']-648*s)/2+y*s
  ActionChains(d).move_by_offset(px,py).click().move_by_offset(-px,-py).perform()
 d.get('http://127.0.0.1:8877/');time.sleep(8)
 click(575,348);time.sleep(4)
 d.refresh();time.sleep(8)
 click(575,414);time.sleep(1)
 d.save_screenshot(str(root/'tools/browser-persist-slot.png'))
 click(108,339);time.sleep(1)
 d.save_screenshot(str(root/'tools/browser-persist-loaded.png'))
 report['state']='captured_for_visual_review'
 report['actions']=['new game','wait4seconds','refresh same origin','open settings','read automatic slot']
except Exception as e:report['state']='failed';report['error']=str(e)
finally:
 d.quit();(root/'tools/browser-persistence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False))
