"""Original cabinet display atlases. Run with Python + Pillow before Blender.

All type, reel symbols, wheel segments and ornament are drawn here; the photo
references inform the cabinet design but are not embedded in the game assets.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/casino_slots'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
FONT = Path('/System/Library/Fonts/Supplemental')
REGIONS = {'title': (0, 0, 1024, 512), 'reels': (0, 520, 1024, 1032),
           'pay': (0, 1040, 1024, 1328), 'wheel': (0, 1344, 640, 1984),
           'labels': (648, 1344, 1024, 1544)}
THEMES = [
    ('classic', 'ROYAL SEVENS', (93, 8, 24), (241, 183, 55)),
    ('wheel', 'FORTUNE WHEEL', (14, 20, 103), (240, 187, 57)),
    ('dual', 'DESERT FORTUNE', (131, 31, 6), (255, 165, 35)),
    ('triple', 'MIDNIGHT GEMS', (13, 26, 97), (54, 211, 240)),
]


def font(size, face='Arial Bold.ttf'):
    return ImageFont.truetype(str(FONT / face), int(size))


def text(im, xy, message, size, fill='#fff1b3', max_width=None, face='Arial Bold.ttf', stroke=1):
    d = ImageDraw.Draw(im)
    f = font(size, face)
    while max_width and d.textbbox((0, 0), message, font=f)[2] > max_width:
        size -= 1
        f = font(size, face)
    d.text((xy[0]+2, xy[1]+3), message, font=f, fill='#160b16', anchor='mm', stroke_width=stroke+1)
    d.text(xy, message, font=f, fill=fill, anchor='mm', stroke_width=stroke, stroke_fill='#422536')


def background(size, dark, accent):
    w, h = size
    im = Image.new('RGB', size)
    p = im.load()
    rng = random.Random(17)
    for y in range(h):
        for x in range(w):
            glow = max(0, 1-math.hypot((x/w-.5)*1.2, (y/h-.40)*.8))
            grain = rng.randrange(-3, 4)
            p[x, y] = tuple(max(0, min(255, int(c*(.32+.7*glow)+grain))) for c in dark)
    d = ImageDraw.Draw(im)
    for offset in [5, 10, 15]:
        d.rounded_rectangle((offset, offset, w-offset-1, h-offset-1), radius=15, outline=accent, width=2 if offset != 10 else 4)
    for x in range(28, w-20, 32):
        d.ellipse((x-2, 22, x+2, 26), fill='#ffdf80')
        d.ellipse((x-2, h-27, x+2, h-23), fill='#ffdf80')
    return im


def diamond(im, cx, cy, r, color=(39, 183, 240)):
    d = ImageDraw.Draw(im)
    points = [(cx-r, cy-r*.25), (cx-r*.5, cy-r*.7), (cx+r*.5, cy-r*.7), (cx+r, cy-r*.25), (cx, cy+r)]
    d.polygon(points, fill=color, outline='#092350', width=3)
    d.polygon([points[0], points[1], (cx, cy-r*.25)], fill='#c7f2ff')
    d.polygon([points[1], points[2], (cx, cy-r*.25)], fill='#84d5f9')
    d.polygon([points[3], points[4], (cx, cy-r*.25)], fill='#1772ac')
    d.line([points[0], points[3]], fill='white', width=2)
    d.line([points[1], points[4], points[2]], fill='#66d9ff', width=2)


def crown(im, cx, cy, r):
    d = ImageDraw.Draw(im)
    pts = [(cx-r,cy-r*.45),(cx-r*.5,cy-r*.1),(cx,cy-r*.9),
           (cx+r*.5,cy-r*.1),(cx+r,cy-r*.45),(cx+r*.75,cy+r*.55),(cx-r*.75,cy+r*.55)]
    d.polygon(pts, fill='#e9b842', outline='#4b210d', width=3)
    d.line((cx-r*.7,cy+r*.25,cx+r*.7,cy+r*.25), fill='#fff3ab', width=4)
    for x in [-.42,0,.42]:
        d.ellipse((cx+x*r-5,cy-3,cx+x*r+5,cy+7), fill='#ab1945', outline='#fff3aa', width=1)


def symbol(im, x, y, size, which):
    if which == 0:
        text(im, (x,y), '7', size*1.65, '#c92133', face='Arial Black.ttf', stroke=2)
    elif which == 1:
        diamond(im,x,y,size*.69)
    elif which == 2:
        crown(im,x,y,size*.63)
    elif which == 3:
        d=ImageDraw.Draw(im)
        for dx in [-.3,.25]:
            d.ellipse((x+size*dx-size*.28,y-size*.2,x+size*dx+size*.28,y+size*.36),fill='#bf122d',outline='#5b1633',width=3)
            d.ellipse((x+size*dx-size*.15,y-size*.08,x+size*dx-size*.04,y+size*.02),fill='#ffc8ac')
            d.line((x+size*dx,y-size*.2,x+size*.15,y-size*.8),fill='#458442',width=5)
        d.ellipse((x+size*.12,y-size*.84,x+size*.55,y-size*.57),fill='#79a737')
    else:
        d=ImageDraw.Draw(im)
        d.rounded_rectangle((x-size*.70,y-size*.3,x+size*.70,y+size*.3),radius=5,fill='#17152b',outline='#b99c67',width=3)
        text(im,(x,y),'BAR',size*.53,'#ffffe0',stroke=0)


def title(kind, name, dark, accent):
    im=background((1024,512),dark,accent);d=ImageDraw.Draw(im)
    # Original sunburst, stepped desert horizon, or gem/star field.
    for i in range(32):
        a=i*math.tau/32
        col=tuple(min(255,int(c*.7+25)) for c in dark)
        d.line((512,300,512+600*math.cos(a),300+600*math.sin(a)),fill=col,width=5)
    if kind == 'dual':
        for r in range(112,0,-1):
            d.ellipse((512-r,277-r,512+r,277+r),fill=(255,160+int(50*(1-r/112)),49))
        d.polygon([(25,431),(94,343),(157,367),(191,319),(252,360),(293,336),(382,447),(490,371),(562,403),(658,340),(711,365),(781,301),(843,363),(935,319),(999,418),(999,480),(25,480)], fill='#6f271f')
        d.polygon([(25,462),(213,408),(283,435),(397,393),(480,466),(637,422),(753,452),(901,389),(999,444),(999,480),(25,480)],fill='#331e39')
    elif kind == 'triple':
        for x,y,r in [(255,294,82),(512,309,117),(778,289,82)]:diamond(im,x,y,r)
    elif kind == 'classic':
        crown(im,512,316,112)
        symbol(im,263,327,91,0);symbol(im,761,327,91,0)
    else:
        for x,i in [(240,0),(512,2),(784,0)]:symbol(im,x,312,105,i)
    text(im,(512,69),'PROGRESSIVE JACKPOT',26,accent,stroke=0)
    text(im,(512,139),name,79,max_width=950,face='Arial Black.ttf',stroke=2)
    text(im,(512,442),'$ 26,174.78',51,'#fffbc5',stroke=1)
    text(im,(512,482),'BONUS PLAY  •  MULTIPLIER WINS',16,accent,stroke=0)
    return im


def reels(kind,dark,accent):
    im=background((1024,512),dark,accent);d=ImageDraw.Draw(im)
    text(im,(512,48),'PLAY MAX CREDITS FOR BONUS',26,accent,stroke=0)
    columns=3 if kind in ['classic','wheel'] else 5
    left=44;right=980;top=84;bottom=421
    cw=(right-left)/columns
    rng=random.Random(kind)
    for c in range(columns):
        x0=int(left+c*cw);x1=int(left+(c+1)*cw-7)
        d.rounded_rectangle((x0,top,x1,bottom),radius=6,fill='#faf1d4',outline='#dda950',width=4)
        for y in range(top+5,bottom-4):
            v=abs((y-(top+bottom)/2)/((bottom-top)/2))
            col=tuple(int(q*(1-.25*v*v)) for q in (250,241,212))
            d.line((x0+5,y,x1-5,y),fill=col)
        for row in range(3):
            yy=top+57+row*109
            which=(0 if row==1 and kind in ['classic','wheel'] else rng.randrange(5))
            symbol(im,(x0+x1)/2,yy,69 if columns==3 else 53,which)
    d.line((32,251,989,251),fill='#d12937',width=2)
    for x,dr in [(25,1),(999,-1)]:d.polygon([(x,242),(x+dr*12,251),(x,260)],fill='#ffca60')
    for x,caption,value in [(180,'CREDIT','$ 842.25'),(512,'BET','$ 3.00'),(842,'WIN','$ 540.00')]:
        text(im,(x,445),caption,16,accent,stroke=0)
        text(im,(x,479),value,31,'#fff9d1',stroke=0)
    return im


def paytable(dark,accent):
    im=background((1024,288),dark,accent);d=ImageDraw.Draw(im)
    text(im,(512,45),'BONUS PAYS • ALL WINS MULTIPLIED',29,accent,stroke=0)
    for row in range(4):
        y=89+row*45
        d.line((40,y+21,984,y+21),fill=tuple(int(c*.4) for c in accent),width=1)
        text(im,(181,y),['7 7 7','BAR BAR BAR','ANY THREE','BONUS WHEEL'][row],24,'#fff2b0',stroke=0)
        for x,mul in [(470,1),(687,2),(873,5)]:
            text(im,(x,y),str([2000,500,100,50][row]*mul),31,accent,stroke=0)
    return im


def wheel():
    im=Image.new('RGB',(640,640),'#16141c');d=ImageDraw.Draw(im)
    cols=['#ffce28','#ee3175','#4bcee4','#72d657','#f78930','#586cec']
    for i in range(24):
        d.pieslice((20,20,620,620),start=i*15-90,end=(i+1)*15-90,fill=cols[i%6],outline='#151938',width=2)
        a=math.radians(i*15+7.5-90)
        txt=Image.new('RGBA',(130,42))
        text(txt,(65,21),str([100,500,50,200,1000,75][i%6]),29,'#101a39',stroke=0)
        txt=txt.rotate(-math.degrees(a)-90,expand=True,resample=Image.Resampling.BICUBIC)
        cx=320+221*math.cos(a);cy=320+221*math.sin(a)
        im.paste(txt,(int(cx-txt.width/2),int(cy-txt.height/2)),txt)
    for r,w,c in [(302,8,'#fff4a5'),(282,3,'#111936'),(100,7,'#f9df7a'),(89,4,'#8b5721')]:
        d.ellipse((320-r,320-r,320+r,320+r),outline=c,width=w)
    d.ellipse((233,233,407,407),fill='#181c57')
    text(im,(320,297),'FORTUNE',26,'#ffdf7a',stroke=0)
    text(im,(320,334),'WHEEL',31,'#ffdf7a',stroke=0)
    return im


for kind,name,dark,accent in THEMES:
    atlas=Image.new('RGB',(1024,2048),'#080a10')
    atlas.paste(title(kind,name,dark,accent),(0,0))
    atlas.paste(reels(kind,dark,accent),(0,520))
    atlas.paste(paytable(dark,accent),(0,1040))
    atlas.paste(wheel(),(0,1344))
    labels=background((376,200),dark,accent)
    text(labels,(188,38),'COLLECT TICKET',24,'#bfeeff',stroke=0)
    text(labels,(188,96),'INSERT BILL / TICKET',22,'#bfeeff',stroke=0)
    text(labels,(188,156),'PLAY MAX • SPIN',26,'#fff5c2',stroke=0)
    atlas.paste(labels,(648,1344))
    atlas.save(OUT/f'{kind}_displays.png')
    print('DRAWN',kind)
