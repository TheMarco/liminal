"""Build the Steam player PDFs from verified controls; no game files are changed."""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader
import json

ROOT = Path(__file__).resolve().parents[3]
PACK = Path(__file__).resolve().parents[1]
OUT = PACK / 'upload'
FONTROOT = Path('/Users/marcovhv/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/libreoffice-headless/libreoffice/LibreOfficeDev.app/Contents/Resources/fonts/truetype')
pdfmetrics.registerFont(TTFont('Body', str(FONTROOT / 'DejaVuSans.ttf')))
pdfmetrics.registerFont(TTFont('BodyBold', str(FONTROOT / 'DejaVuSans-Bold.ttf')))
pdfmetrics.registerFont(TTFont('Display', '/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf'))
pdfmetrics.registerFontFamily('Body', normal='Body', bold='BodyBold', italic='Body', boldItalic='BodyBold')

W, H = 595.276, 841.89
M = 44
CW = W - M * 2
PAPER = HexColor('#F3EFE4')
INK = HexColor('#202620')
DIM = HexColor('#62685D')
RULE = HexColor('#CEC7B9')
RED = HexColor('#6F2B21')
TEAL = HexColor('#244F4D')

def text(c, s, x, top, size=10.5, font='Body', color=INK):
    c.setFillColor(color)
    c.setFont(font, size)
    c.drawString(x, H - top - size * .82, s)

def para(c, s, x, top, width=CW, size=10.5, color=INK, leading=None):
    st = ParagraphStyle('body', fontName='Body', fontSize=size,
                        leading=leading or size * 1.5, textColor=color,
                        spaceBefore=0, spaceAfter=0)
    p = Paragraph(s, st)
    _, height = p.wrap(width, H)
    if top + height > H - 52:
        raise ValueError(f'Page overflow: {s[:50]} at {top + height}')
    p.drawOn(c, x, H - top - height)
    return top + height

def line(c, top, x=M, width=CW, color=RULE):
    c.setStrokeColor(color)
    c.setLineWidth(.6)
    c.line(x, H - top, x + width, H - top)

def base(c, page, total, label='PLAYER GUIDE'):
    c.setFillColor(PAPER)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    text(c, 'IT WANTS YOU TO STAY', M, 27, 10, 'Display', DIM)
    c.setFont('Body', 7.6)
    c.setFillColor(DIM)
    c.drawRightString(W-M, H-35, label)
    line(c, 48)
    line(c, H-41)
    text(c, 'AI & DESIGN GAME STUDIOS', M, H-28, 7.4, 'Body', DIM)
    c.setFont('Body', 7.4)
    c.drawRightString(W-M, 22, f'{page:02d} / {total:02d}')

def heading(c, title, subtitle, top=70):
    text(c, title, M, top, 38, 'Display')
    text(c, subtitle, M, top+44, 8.5, 'Body', DIM)

def section(c, number, title, body, top):
    text(c, number, M, top+1, 22, 'Display', RED)
    text(c, title, M+37, top, 20, 'Display')
    return para(c, body, M+37, top+28, CW-37) + 28

def callout(c, title, body, top, height=92):
    c.setFillColor(INK)
    c.rect(M, H-top-height, CW, height, fill=1, stroke=0)
    text(c, title, M+18, top+16, 24, 'Display', PAPER)
    para(c, body, M+18, top+47, CW-36, 9.7, PAPER, 14.5)

def table(c, rows, top, key_width=178, row_height=27, size=10):
    c.setFillColor(TEAL)
    c.rect(M, H-top-25, CW, 25, fill=1, stroke=0)
    text(c, 'INPUT', M+12, top+8, 8, 'BodyBold', PAPER)
    text(c, 'ACTION', M+key_width+12, top+8, 8, 'BodyBold', PAPER)
    y=top+25
    for idx,(key,action) in enumerate(rows):
        if idx % 2 == 0:
            c.setFillColor(HexColor('#E7E4D9'))
            c.rect(M,H-y-row_height,CW,row_height,fill=1,stroke=0)
        text(c,key,M+12,y+8,size,'BodyBold')
        text(c,action,M+key_width+12,y+8,size,'Body')
        y += row_height
    line(c,y)
    return y

def finish(c):
    c.showPage()

def new_pdf(path,title):
    c=canvas.Canvas(str(path),pagesize=(W,H),pageCompression=1)
    c.setTitle(title)
    c.setAuthor('AI & Design Game Studios')
    c.setSubject('Player instructions for It wants you to stay')
    return c

controls = [
    ('WASD / arrow keys', 'Move'),
    ('Mouse / trackpad', 'Look'),
    ('Shift', 'Sprint'),
    ('E', 'Interact with the focused object'),
    ('F', 'Toggle the flashlight'),
    ('C', 'Raise / lower camera (Descent)'),
    ('Space', 'Take photo with camera raised'),
    ('Hold right mouse', 'Raise camera (Descent)'),
    ('Left mouse', 'Take photo with camera raised'),
    ('P', 'Open / close photo album'),
    ('Esc', 'Pause / resume, or cancel a view'),
    ('Q', 'Request a return to the title'),
]

manual=OUT/'it-wants-you-to-stay-player-guide.pdf'
c=new_pdf(manual,'It wants you to stay - Player Guide')

# 1. Start here: retain the campaign's visual identity without spoiling its story.
base(c,1,4)
c.drawImage(str(OUT/'header-capsule-920x430.png'), 0, H-280, width=W, height=278.23, mask='auto')
c.setFillColor(PAPER)
c.rect(0,H-62,W,62,fill=1,stroke=0)
text(c,'PLAYER GUIDE',M,25,24,'Display')
text(c,'START HERE  /  KEYBOARD + MOUSE',M,292,8.5,'Body',DIM)
text(c,'The building is waiting.',M,318,35,'Display')
para(c,'A short guide to exploring, photographing and surviving <b>It wants you to stay</b>. '
       'The story is yours to discover.',M,365)
col=(CW-28)/2
text(c,'DESCENT',M,427,24,'Display',RED)
para(c,'Follow the story through eleven floors. Photograph unnatural subjects, find the next elevator, '
       'and watch the recordings left behind. Creatures and blackouts threaten your progress.',M,462,col,10.2)
text(c,'WANDER',M+col+28,427,24,'Display',TEAL)
para(c,'Explore the eleven worlds freely, without pursuing enemies. Use the floor keys to move between '
       'environments and take your time with the building.',M+col+28,462,col,10.2)
callout(c,'WHEN THE LIGHTS FAIL, STAND STILL.',
        'In Descent, stop moving during a blackout. Wait for the lights to return before continuing.',591,95)
para(c,'<b>Before starting:</b> open Settings to choose your mouse sensitivity, field of view, '
       'head bob, subtitles and visual effects. You can pause and revisit these options during play.',M,716,size=10)
finish(c)

# 2. Controls: key names match scripts/game_input.gd and the camera handlers.
base(c,2,4)
heading(c,'YOUR CONTROLS','DEFAULT QWERTY BINDINGS  /  MAIN KEYS CAN BE REMAPPED IN SETTINGS')
y=table(c,controls,150,row_height=28,size=9.8)
para(c,'The game shows prompts for your current bindings and keyboard layout. Esc remains menu / cancel. '
       'Floor-selection keys are reserved for Wander. Click the game view if you need to recapture the mouse.',M,y+18,size=9.4)
text(c,'INSIDE THE PHOTO ALBUM',M,602,23,'Display')
table(c,[('Left / right arrows','Previous / next photograph'),
         ('Mouse wheel / + / -','Zoom'),
         ('Drag / WASD','Pan the selected photograph'),
         ('0','Fit the photograph to the view'),
         ('P / Esc','Close the album')],636,key_width=178,row_height=22,size=9.4)
finish(c)

# 3. Progress and survival: deliberately avoid explaining the mystery or ending.
base(c,3,4)
heading(c,'MAKE YOUR WAY DOWN','DESCENT  /  PHOTOGRAPHS, RECORDINGS AND LIGHT')
y=section(c,'01','DOCUMENT THE UNNATURAL',
          'Raise the camera with C, frame something that does not belong, and press Space. '
          'The on-screen evidence counter shows your progress. Ordinary scenery and repeat photographs '
          'can still be kept in your album, but repeating the same subject does not earn new evidence.',158)
y=section(c,'02','FOLLOW THE RECORDINGS',
          'Find the objective elevator room and use its television. Complete the recording to unlock '
          'the lift. Esc pauses playback. Follow the on-screen E prompt: an unfinished recording stops '
          'and rewinds; a recording you have already completed can be skipped.',y)
y=section(c,'03','KEEP LIGHT IN RESERVE',
          'Use F to switch on the flashlight and aim its beam at an approaching creature. '
          'The battery is limited and does not refill by itself. Look for the blue-lit charging stations '
          'and interact with E. Charging takes time; stay alert. You can interrupt it and retain '
          'the charge already gained.',y)
y=section(c,'04','PAUSE. THEN CONTINUE.',
          'Esc pauses play. Continue resumes your saved Descent checkpoint in the same building. '
          'Documented evidence, completed objective recordings and the current run\'s album survive '
          'death and Continue. You may return at an arrival elevator rather than your exact last position.',y)
callout(c,'A NEW DESCENT IS A NEW BUILDING.',
        'New Descent and Restart Descent begin again from the first floor and reset the current run\'s progress.',y+2,94)
finish(c)

# 4. World selection and comfort: relevant instructions, not speculative hardware claims.
base(c,4,4)
heading(c,'EXPLORE AT YOUR OWN PACE','WANDER  /  FLOOR KEYS AND COMFORT SETTINGS')
para(c,'These floor shortcuts are available in Wander. In Descent, follow the campaign\'s route '
       'and elevators instead.',M,150)
floors=[('1','Casino'),('2','Office'),('3','Annex'),('4','Airport'),('5','Asylum'),
        ('6','School'),('7','Mall'),('8','Prison'),('9','Poolrooms'),('0','Data Center'),('-','Bloom')]
for i,(key,name) in enumerate(floors):
    colidx=i//6; rowidx=i%6
    x=M+colidx*(CW/2+5)
    top=207+rowidx*31
    text(c,key,x,top,18,'Display',RED)
    text(c,name,x+30,top+3,10.3)
line(c,408)
text(c,'MAKE THE VIEW YOURS',M,431,27,'Display')
y=para(c,'Open Settings from the title or pause menu. Your choices are saved between launches.',M,469)
settings=[
    ('Movement and view','Adjust sensitivity, field of view, head bob, invert Y and toggle sprint.'),
    ('Reduced Flashing','Reduces rapid visual effects and removes the camera flash.'),
    ('VHS and CRT','Enable either effect, combine them, or switch both off. VHS strength is adjustable.'),
    ('Audio and subtitles','Set music, effects and dialogue levels separately; enable story subtitles.'),
    ('Display and feedback','Choose fullscreen, HDR preferences and optional cause-of-death explanations.'),
]
y += 23
for title,body in settings:
    y=para(c,f'<b>{title}.</b> {body}',M,y,size=10)+15
finish(c)
c.save()

# A separate, genuinely single-page quick reference for the Steam manual slot.
quick=OUT/'it-wants-you-to-stay-quick-reference.pdf'
c=new_pdf(quick,'It wants you to stay - Quick Reference')
base(c,1,1,'QUICK REFERENCE')
heading(c,'KEEP THIS CLOSE.','DEFAULT CONTROLS  /  CHANGE MAIN KEY BINDINGS IN SETTINGS',70)
callout(c,'WHEN THE LIGHTS FAIL, STAND STILL.',
        'Descent: stop moving during a blackout. Wait for the lights to return.',141,81)
table(c,controls,240,row_height=24,size=9.5)
text(c,'DESCENT',M,575,20,'Display',RED)
para(c,'C raises the camera; Space takes the photograph. P opens your album. '
       'Document new anomalies, complete the elevator-room recording, then use the lift. '
       'F controls the flashlight; E uses charging stations.',M,603,size=9.5)
text(c,'WANDER FLOOR KEYS',M,664,20,'Display',TEAL)
para(c,'<b>1</b> Casino &nbsp; <b>2</b> Office &nbsp; <b>3</b> Annex &nbsp; <b>4</b> Airport &nbsp; <b>5</b> Asylum '
       '&nbsp; <b>6</b> School<br/><b>7</b> Mall &nbsp; <b>8</b> Prison &nbsp; <b>9</b> Poolrooms '
       '&nbsp; <b>0</b> Data Center &nbsp; <b>-</b> Bloom',M,692,size=9.3,leading=16)
para(c,'<b>Comfort:</b> Esc opens the pause menu. Settings includes head bob, reduced flashing, '
       'story subtitles and separate VHS / CRT toggles.',M,744,size=9.1,leading=13)
finish(c)
c.save()

checks=[]
for path,count in [(manual,4),(quick,1)]:
    reader=PdfReader(path)
    assert len(reader.pages)==count,(path,len(reader.pages))
    assert all(page.extract_text().strip() for page in reader.pages)
    checks.append({'file':path.name,'pages':len(reader.pages),'bytes':path.stat().st_size})
print(json.dumps(checks,indent=2))
