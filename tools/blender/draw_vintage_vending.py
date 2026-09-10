"""Original period advertising and labels, drawn specifically for these cabinets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import random,math
ROOT=Path(__file__).resolve().parents[2]
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
SERIF='/System/Library/Fonts/Supplemental/Georgia.ttf'
def txt(d,xy,t,s,c,face=BOLD):d.text(xy,t,font=ImageFont.truetype(face,s),fill=c)
def make(kind):
    rng=random.Random(1986)
    im=Image.new('RGB',(1024,1024),'#c5b687');d=ImageDraw.Draw(im)
    if kind=='vegas_cigarette_machine':
        for y in range(800):
            t=y/800;d.line((0,y,1024,y),fill=(int(15+120*t),int(40+100*t),int(83+71*t)))
        # Printed Alpine scene: layered ridgelines, blue shadow facets and broken snow caps.
        for layer in range(3):
            base=440+layer*95
            peaks=[(-50,base+110)]
            for x in range(0,1100,90):peaks.append((x,base+rng.randrange(-180,65)))
            d.polygon(peaks+[(1100,800),(-100,800)],fill=['#526f9d','#294772','#1c345a'][layer])
            for j in range(1,len(peaks)-1):
                x,y=peaks[j];nx,ny=peaks[j+1]
                d.polygon([(x,y),(x-45,y+92),(x-12,y+55),(x+11,y+71),(x+28,y+45),(nx,ny)],fill=['#e2e2da','#d3dedf','#adccd7'][layer])
                d.polygon([(x,y),(x+6,y+112),(nx,ny)],fill=['#6581a5','#41638c','#35547c'][layer])
        txt(d,(120,49),'ALPINE',148,'#f6e0ac',FONT)
        txt(d,(235,215),'FILTER CIGARETTES',35,'#ece3c3',FONT)
        txt(d,(203,716),'THE COOL OF THE MOUNTAINS',25,'#e8e3c6',FONT)
        names=['ALPINE','ROYAL','SUMMIT','MESA','PARK','NORTH','GOLD','CREST','BLUE','VALE']
        colors=['#25533a','#711f31','#b29238','#ac392e','#263b60','#286864','#ac8c36','#714036','#234b80','#7b502a']
        for row in range(2):
            top=800+row*112;d.rectangle((0,top,1024,top+110),fill='#e8ddc1')
            for j,n in enumerate(names):
                x=j*102+5;d.rectangle((x,top+8,x+90,top+57),fill=colors[(j+row)%10])
                txt(d,(x+5,top+20),n,15,'#fff5dd')
                txt(d,(x+15,top+65),'$1.25',16,'#322b20')
                txt(d,(x+27,top+87),'PULL',11,'#51432f')
    else:
        for y in range(800):
            t=y/800;d.line((0,y,1024,y),fill=(int(13+40*t),int(37+53*t),int(33+10*t)))
        # Hundreds of shaded beans form the illustrated coffee harvest background.
        for i in range(640):
            x=rng.randrange(-25,1050);y=rng.randrange(200,820);rx=rng.randrange(9,23);ry=rng.randrange(6,14)
            col=rng.choice(['#594020','#75532c','#926a37','#a87d44','#44311d'])
            d.ellipse((x-rx,y-ry,x+rx,y+ry),fill=col,outline='#312a1b',width=2)
            d.arc((x-rx+5,y-ry,x+rx-5,y+ry),80,260,fill='#c09b61',width=2)
        # Enamel coffee pot with a long spout, a full paper cup and rising steam.
        d.polygon([(28,236),(157,191),(335,221),(366,438),(281,530),(83,458)],fill='#c7b487')
        d.polygon([(65,237),(157,213),(322,239),(347,296),(84,283)],fill='#eee0b2')
        d.polygon([(332,296),(501,213),(524,231),(371,375)],fill='#d4c99c')
        d.ellipse((94,189,306,239),fill='#e0d0a3',outline='#7b6d49',width=5)
        d.arc((13,266,149,403),70,285,fill='#d8c294',width=25)
        d.polygon([(585,390),(887,390),(846,678),(633,678)],fill='#e0c97e')
        d.ellipse((585,365,887,422),fill='#faf0c0',outline='#c0ad72',width=5)
        d.ellipse((607,377,866,409),fill='#45321e')
        d.arc((843,420,954,574),270,90,fill='#ecd591',width=22)
        for yy in [438,511,584]:txt(d,(644,yy),'Coffee',42,'#5a5327',SERIF)
        for x in [691,751,812]:d.arc((x-25,237,x+26,365),75,250,fill='#c4c7a7',width=4)
        txt(d,(60,29),'FRESHLY BREWED',49,'#f3ddb1',SERIF)
        txt(d,(107,96),'Coffee • Chocolate • Tea',44,'#e4cc8e',SERIF)
        txt(d,(52,727),'A WARM MOMENT IN YOUR DAY',31,'#f3ddb1',SERIF)
        names=['BLACK','CREAM','SUGAR','REGULAR','DECAF','COCOA','TEA','SOUP']
        d.rectangle((0,800,1024,1024),fill='#a79057')
        for j,n in enumerate(names):
            x=j*128+8;d.rectangle((x,815,x+112,912),fill='#48392a',outline='#e1c78a',width=3)
            txt(d,(x+8,838),n,17,'#f2e2b3');txt(d,(x+27,874),'35¢',21,'#f2e2b3')
            txt(d,(x+23,949),'SELECT',14,'#342b1e')
    # Subtle print grain, not high-contrast scratches across the artwork.
    pix=im.load()
    for y in range(1024):
        for x in range(1024):
            c=pix[x,y];n=rng.randint(-3,3);pix[x,y]=tuple(max(0,min(255,v+n)) for v in c)
    out=ROOT/'art'/kind;out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').write_text('');
    # Keep selector graphics untouched; pack the original generated advertisement
    # into the existing poster UV region so runtime stays one 1K atlas.
    source=out/'advertising_source_imagegen.png'
    if source.exists():
        poster=Image.open(source).convert('RGB').resize((1024,800),Image.Resampling.LANCZOS)
        im.paste(poster,(0,0))
    im.save(out/'advertising.png')
for kind in ['vegas_cigarette_machine','office_coffee_machine']:make(kind)
