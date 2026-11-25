"""Analyze alpha only; write sprite anchor metadata without changing artwork."""
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
result={}
for name,columns in [("side",4),("vertical",8),("south",4)]:
    filename="residents-"+name+"-16bit-"+("v5" if name=="south" else "v4")+".png"
    image=Image.open(root/"assets/art"/filename).convert("RGBA")
    width,height=image.size
    frames=[]
    for row in range(7):
        for column in range(columns):
            x,y=round(column*width/columns),round(row*height/7)
            tile=image.crop((x,y,round((column+1)*width/columns),round((row+1)*height/7)))
            mask=tile.getchannel("A").point(lambda value:255 if value>=128 else 0)
            left,top,right,bottom=mask.getbbox()
            band_top=bottom-max(2,round((bottom-top)*.12))
            foot=mask.crop((0,band_top,tile.width,bottom)).getbbox()
            anchor_x=(foot[0]+foot[2])/2
            frames.append({"region":[x+left,y+top,right-left,bottom-top],"anchor":[anchor_x-left,bottom-top],"height":bottom-top})
    # Keep scale constant over a walk cycle, calibrate each direction independently.
    for start in range(0,len(frames),4):
        reference=max(frame["height"] for frame in frames[start:start+4])
        for frame in frames[start:start+4]:frame["reference_height"]=reference
    result[name]=frames
(root/"assets/art/residents-anchors-v4.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
