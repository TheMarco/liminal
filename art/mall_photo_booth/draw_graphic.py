from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
out=Path(__file__).parent
im=Image.new('RGB',(400,1024),'#dedbd0');d=ImageDraw.Draw(im)
f='/System/Library/Fonts/Supplemental/Arial.ttf'
b='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def text(p,s,n=38,font=b):d.text(p,s,font=ImageFont.truetype(font,n),fill='#242b29')
text((25,36),'the',45);text((25,87),'snapshot',47);text((25,140),'photo',47);text((25,193),'booth.',47)
for poly,c in [([(25,295),(255,400),(270,365),(40,260)],'#ca573b'), ([(270,405),(380,545),(350,575),(240,440)],'#235c91'), ([(20,490),(185,620),(211,585),(46,455)],'#bf7881'), ([(80,644),(270,585),(282,623),(92,682)],'#e7b763'), ([(282,755),(370,844),(335,865),(248,780)],'#337871'), ([(22,755),(130,725),(142,761),(34,791)],'#375b78')]:d.polygon(poly,fill=c)
text((51,904),'FOUR POSES',28);text((76,944),'ONE MEMORY',23,font=f)
im.save(out/'graphic.png')
