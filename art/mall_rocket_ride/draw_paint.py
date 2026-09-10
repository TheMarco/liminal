"""Original smooth top-projected fiberglass paint, baked into shared body atlas."""
from PIL import Image,ImageDraw
from pathlib import Path
S=2048;im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
def pts(a):return [((x/.8+.5)*S,(.8-z)/.9*S) for x,z in a]
def poly(a,c):d.polygon(pts(a),fill=c)
poly([(-.253,.22),(-.249,.34),(-.221,.47),(-.151,.59),(-.072,.66),(.072,.66),(.151,.59),(.221,.47),(.249,.34),(.253,.22)],'#ded9ba')
poly([(-.023,.22),(-.039,.30),(-.061,.41),(-.092,.51),(-.11,.59),(.11,.59),(.092,.51),(.061,.41),(.039,.30),(.023,.22)],'#b91920')
for side in [-1,1]:
 poly([(side*x,z) for x,z in [(.025,.055),(.245,.11),(.20,.245),(.03,.28)]],'#172026')
 poly([(side*x,z) for x,z in [(.038,.075),(.229,.116),(.188,.23),(.042,.26)]],'#e1d623')
im.resize((1024,1024),Image.Resampling.LANCZOS).save(Path(__file__).parent/'top_paint.png')
