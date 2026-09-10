"""Original printed instrument/retail graphics; no reference-image pixels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/hero_props';OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').write_text('')
im=Image.new('RGB',(1024,1024),(26,34,37));d=ImageDraw.Draw(im)
def font(n,bold=False):return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial'+(' Bold' if bold else '')+'.ttf',n)
def text(t,x,y,size=16,color=(230,231,217),bold=False):d.text((x,y),t,font=font(size,bold),fill=color)
for row in range(4):
 for col in range(4):d.rectangle((col*256,row*256,col*256+255,row*256+255),fill=(23,32,36),outline=(140,145,130),width=2)
# Airport arrivals screen, tile 0.
d.rectangle((2,2,254,46),fill=(225,186,27));text('BAGGAGE ARRIVALS',10,14,21,(20,25,26),True)
text('FLIGHT    ORIGIN          BELT',12,57,14,(135,203,224),True)
for i,(f,c) in enumerate([('LW 082','SAN FRANCISCO'),('LW 319','CHICAGO'),('LW 116','LOS ANGELES'),('LW 407','DENVER'),('LW 201','SEATTLE'),('LW 628','NEW YORK')]):
 y=86+i*23;d.line((10,y+20,244,y+20),fill=(65,86,97));text(f,10,y,14);text(c,73,y,12);text('02',222,y,14,(249,210,63))
text('PLEASE KEEP CLEAR OF BELT',15,234,12,(216,186,100))
# Warning/service plate, tile 1.
d.rectangle((259,3,509,253),fill=(186,165,65));text('CAUTION',275,12,38,(22,28,30),True)
d.polygon([(382,64),(445,166),(319,166)],fill=(23,29,30));text('!',373,88,59,(227,199,86),True)
text('AUTOMATIC MACHINERY',269,179,17,(20,24,22),True);text('KEEP HANDS CLEAR',285,206,16,(20,24,22));text('SERVICE ACCESS  /  08',283,231,12,(20,24,22))
# Incubator main monitoring display tile 2.
d.rectangle((515,3,765,253),fill=(7,35,38));text('VESSEL / 07',530,12,28,(78,239,207),True);text('BIOLOGICAL CONTAINMENT',526,50,13,(166,221,209))
for y in range(78,192,17):d.line((529,y,747,y),fill=(16,67,65))
points=[]
for i in range(214):
 pulse=(i%61);h=0 if pulse>14 else ([-1,-4,1,5,12,-38,34,12,-8,-4,0,2,0,0,0][pulse])
 points.append((532+i,126+h+math.sin(i*.12)*2))
d.line(points,fill=(65,246,185),width=3);text('TEMP  32.6 C',529,184,21,(190,243,206));text('O2  87%   ACTIVE',529,214,18,(242,196,77))
# Serial/service details, tile 3.
text('L A Z A R U S',788,20,27,bold=True);text('BIOLOGICS DIVISION',789,55,16);d.line((782,83,1008,83),fill=(164,165,149),width=2)
text('INCUBATION SYSTEM',790,100,18,bold=True);text('MODEL   LX - 07',790,132,17);text('SERIAL  86 / 00419',790,160,16)
for i in range(90):
 if i%5 in (0,1,3):d.rectangle((788+i*2,195,789+i*2,232),fill=(224,224,206))
# Fictional mall identity tile 4, luminous white panel, colored ribbon.
d.rectangle((2,258,254,510),fill=(224,223,207))
colors=[(249,154,37),(232,58,59),(179,53,126),(68,122,185)]
for i in range(40):
 t=i/39;x=55+t*146;y=296+37*math.sin(t*math.tau-1.1)
 d.line((x,y,x+4,y+19),fill=colors[min(3,i//10)],width=10)
text('Z E O N',24,375,43,(30,37,38),True);text('DEPARTMENT STORES',29,432,17,(133,92,38));text('SINCE 1968',80,467,14,(107,104,85))
# Small retail POS screen tile 5.
d.rectangle((259,259,509,509),fill=(20,50,47));text('ZEON  /  REGISTER 03',269,274,17,(178,221,191),True)
for i,(a,b) in enumerate([('KNITWEAR','29.95'),('COTTON SHIRT','18.50'),('SALES TAX','3.39')]):text(a,274,326+i*32,15);text(b,454,326+i*32,15)
d.line((273,434,493,434),fill=(163,200,173));text('TOTAL',274,453,21,bold=True);text('51.84',429,453,21,(240,215,117),True)
# Narrow machine stripes + hatch stencils tile 6.
d.rectangle((514,258,766,510),fill=(172,153,64))
for x in range(490,800,45):d.polygon([(x,258),(x+23,258),(x-57,510),(x-80,510)],fill=(39,45,40))
# Atmospheric readout tile 7.
d.rectangle((770,258,1022,510),fill=(12,47,48));text('PRESSURE',792,277,30,(110,228,196),True);text('1.04',789,329,78,(148,252,221),True);text('BAR   /   STABLE',795,423,21,(231,206,121));text('DO NOT BREAK SEAL',790,477,17,(173,216,197))
# neutral maintenance/access plate tile 8.
d.rectangle((2,514,254,766),fill=(165,176,161));text('ACCESS  02',17,533,28,(38,49,43),True);text('AUTHORIZED',25,589,23,(39,47,41),True);text('PERSONNEL ONLY',20,622,22,(39,47,41));text('ISOLATE BEFORE SERVICE',13,682,16,(44,48,40));text('110 / 240 V   50-60 Hz',19,718,16,(44,48,40))
im.save(OUT/'labels.png')
rubber=Image.new('RGB',(256,64),(33,37,38));rd=ImageDraw.Draw(rubber)
for x in range(0,256,32):
 rd.rectangle((x,0,x+2,63),fill=(6,9,10));rd.line((x+3,0,x+3,63),fill=(63,67,66))
for y in range(4,64,7):rd.line((0,y,255,y),fill=(36,40,41))
rubber.save(OUT/'carousel_belt.png')
print(OUT/'labels.png')
