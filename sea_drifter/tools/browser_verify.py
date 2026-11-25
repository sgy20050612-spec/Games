import json,time,pathlib,traceback
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
root=pathlib.Path(__file__).resolve().parents[1];report={'state':'starting','checks':[]}
out=root/'tools/browser-verification.json'
options=Options();options.add_argument('-headless')
driver=None
try:
 driver=webdriver.Firefox(options=options)
 driver.set_window_size(1280,800);driver.set_page_load_timeout(60)
 driver.get('http://127.0.0.1:8877/')
 time.sleep(10)
 driver.save_screenshot(str(root/'tools/browser-main.png'))
 report['title']=driver.title
 report['body_text']=driver.find_element('tag name','body').text
 canvas=driver.find_element('id','canvas')
 rect=canvas.rect;report['canvas']=rect
 def click_game(x,y):
  bounds=driver.execute_script('const r=document.getElementById("canvas").getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};')
  # Godot logical viewport keeps the1152x648 aspect ratio within the canvas.
  scale=min(bounds['w']/1152,bounds['h']/648)
  px=bounds['x']+(bounds['w']-1152*scale)/2+x*scale
  py=bounds['y']+(bounds['h']-648*scale)/2+y*scale
  ActionChains(driver).move_by_offset(px,py).click().move_by_offset(-px,-py).perform()
 click_game(575,348);time.sleep(1)
 driver.save_screenshot(str(root/'tools/browser-playing.png'))
 ActionChains(driver).send_keys(Keys.TAB).perform();time.sleep(.5)
 click_game(440,143);time.sleep(.5)
 driver.save_screenshot(str(root/'tools/browser-tree.png'))
 report['checks']=['HTTP page loaded','canvas present','start button click sent','Tab key and tree-tab click sent']
 report['state']='captured_for_visual_review'
except Exception as e:
 report['state']='failed';report['error']=str(e);report['trace']=traceback.format_exc()
finally:
 if driver:driver.quit()
 out.write_text(json.dumps(report,ensure_ascii=False,indent=2))
 print(json.dumps(report,ensure_ascii=False))
