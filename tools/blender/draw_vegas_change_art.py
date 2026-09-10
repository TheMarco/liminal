"""Original face printing for the reference-inspired change cabinet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/vegas_change_machine'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').write_text('')
im=Image.new('RGB',(1024,1024))
r=random.Random(86)
pixels=im.load()
for y in range(1024):
    for x in range(1024):
        n=r.randrange(-3,4)
        pixels[x,y]=(91+n,68+n,58+n)
d=ImageDraw.Draw(im)
font='/System/Library/Fonts/Helvetica.ttc'
bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
cream='#f4edc9'
dark='#5a351d'
def text(x,y,s,size=20,color=cream,face=bold):
    d.text((x,y),s,font=ImageFont.truetype(face,size),fill=color)
d.rectangle((42,40,982,215),outline=cream,width=5)
header=ImageFont.truetype(bold,190)
label='CHANGE'
box=d.textbbox((0,0),label,font=header)
hx=512-(box[2]-box[0])//2
hy=57-(box[1]-box[0])
d.text((hx,hy),label,font=header,fill=cream)
d.rectangle((50,265,610,440),outline=cream,width=4)
d.rectangle((64,279,596,426),outline='#d1a65a',width=2)
panel_font=ImageFont.truetype(bold,61)
panel=' $1 or $5 BILLS'
pbox=d.textbbox((0,0),panel,font=panel_font)
d.text((330-(pbox[2]-pbox[0])//2,325),panel,font=panel_font,fill=cream)
text(718,287,'INSERT BILL',15)
text(719,309,'FACE UP',12)
# The clean front reference has an outlined lower stripe and no service stickers.
d.rectangle((42,886,982,965),outline=cream,width=3)
d.ellipse((922,900,970,949),outline=cream,width=2)
text(931,916,'M',16)
# Small out-of-service indicator beside the header.
d.ellipse((936,151,953,168),fill='#943622',outline='#e4d9c2',width=2)
text(904,99,'TEMPORARILY',8)
text(913,112,'OUT OF SERVICE',7)
# Small wear marks on the powder-coated face, without using photo pixels.
for i in range(85):
    x=r.randrange(12,1012); y=r.randrange(12,1012)
    if r.random()<.5:d.line((x,y,x+r.randrange(1,8),y),fill='#6b5133',width=1)
im.save(OUT/'face_print.png')
