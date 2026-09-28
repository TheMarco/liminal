#!/usr/bin/env python3
"""Reproducible promotional edit from Godot-rendered footage and game audio."""
import argparse
import json
import math
import pathlib
import subprocess
import wave
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/promo-trailer-v6'
V5_FOOTAGE = ROOT / 'build/promo-trailer-v5'
NEW_FOOTAGE = {'annex_flood', 'portal'}
FOOTAGE = ROOT / 'build/promo-trailer-v3'
PREVIOUS = ROOT / 'build/promo-trailer'
RECAPTURED = {'casino_traverse','office_traverse','school_traverse','server_traverse','annex_traverse','pool_grand','death'}
OUT = ROOT / 'deliverables/promo_trailer'
FF = '/usr/local/bin/ffmpeg'
FPS, SR = 30, 48000
# name, timeline start/end frames, source start/end frames (exclusive).
# Shot lengths stay at native speed; every feature card is a 1.5-second beat.
SHOT_LENGTHS = [
 ('intro',60,0), ('cross_warning',59,5), ('casino_kill',75,30),
 ('card_explore',45,0), ('casino_traverse',120,12), ('office_traverse',120,12),
 ('pool_grand',120,12), ('pool_floaties',60,10), ('pool_girl',105,12),
 ('card_fight',45,0), ('office_kill',75,30), ('school_traverse',105,12),
 ('school_kill',75,30), ('server_traverse',105,12), ('server_kill',60,48),
 ('annex_traverse',105,12), ('card_alive',45,0), ('wave',135,15),
 ('annex_flood',120,12), ('doors',108,0), ('card_preview',45,0),
 ('portal',210,0), ('cross_stay',105,35), ('death',75,0), ('title',135,0),
]
EDIT=[]
for name,length,source_in in SHOT_LENGTHS:
    start=EDIT[-1][2] if EDIT else 0
    EDIT.append((name,start,start+length,source_in,source_in+length))
FRAME_COUNT = EDIT[-1][2]
DURATION = FRAME_COUNT / FPS

CARDS = {
    'card_explore': dict(lines=['EXPLORE', 'THE IMPOSSIBLE.'],
        sub='', background=('casino_traverse',75)),
    'card_fight': dict(lines=['FIGHT', 'WITH LIGHT.'],
        sub='', background=('office_kill',40)),
    'card_alive': dict(lines=['THE BUILDING', 'IS ALIVE.'],
        sub='', background=('wave',75)),
    'card_preview': dict(lines=['PREVIEW YOUR', 'NEXT NIGHTMARE.'],
        sub='', background=('portal',110)),
}

def source(name, frame):
    # Cut the five source-world flash frames at the native realm handoff.
    # The following frames are the real destination fade-in and player walk.
    if name == 'portal' and frame >= 115: frame += 5
    root = BUILD if name in NEW_FOOTAGE else (V5_FOOTAGE if name in RECAPTURED else (PREVIOUS if name.startswith('cross_') or name == 'annex' else FOOTAGE))
    return Image.open(root / 'raw' / name / f'frame-{frame:04d}.jpg').convert('RGB')

def title_layer():
    im = Image.new('RGBA',(1920,1080))
    d = ImageDraw.Draw(im)
    cream = (237,231,213,255)
    title_font = '/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf'
    f = ImageFont.truetype(title_font,205)
    # The game's recurring doorway mark, drawn as type-card linework.
    for box in [(274,258,500,626),(325,313,447,626),(366,366,408,626)]:
        d.line([(box[0],box[3]),(box[0],box[1]),(box[2],box[1]),(box[2],box[3])],fill=cream,width=10)
    for txt,y in [('IT WANTS',225),('YOU TO STAY',426)]:
        d.text((590+3,y+2),txt,font=f,fill=(85,27,24,220))
        d.text((590,y),txt,font=f,fill=cream)
    for txt,y,sz,col,font in [
        ('THE ULTIMATE PSYCHOLOGICAL HORROR GAME',681,39,(194,191,177,255),str(ROOT/'fonts/VT323-Regular.ttf')),
        ('COMING SOON TO STEAM',807,61,cream,title_font),
        ('By @AIandDesign',914,39,(179,184,177,255),str(ROOT/'fonts/VT323-Regular.ttf'))]:
        font=ImageFont.truetype(font,sz)
        b=d.textbbox((0,0),txt,font=font)
        d.text(((1920-b[2])/2,y),txt,font=font,fill=col)
    return im

def title_frame(f, layer):
    bg=source('annex',40)
    bg=ImageEnhance.Brightness(bg).enhance(.11)
    # Short analog title lock, then a long readable hold.
    if f in (1,3,6):
        layer=layer.transform(layer.size,Image.Transform.AFFINE,(1,0,7 if f==3 else -4,0,1,0))
    bg=Image.alpha_composite(bg.convert('RGBA'),layer).convert('RGB')
    if f >= 126: bg=ImageEnhance.Brightness(bg).enhance(max(0,(135-f)/9))
    return bg

def intro_frame(f, layer):
    # A dedicated two-second title opening, with the warning heard underneath.
    # Only the title and doorway mark appear here; the closing card keeps the CTA.
    opening=Image.new('RGBA',(1920,1080))
    opening.paste(layer.crop((0,0,1780,650)),(140,110))
    rng=np.random.default_rng(2100+f)
    grain=np.clip(rng.normal(5,2,(270,480)),0,12).astype(np.uint8)
    bg=Image.fromarray(grain).resize((1920,1080),Image.Resampling.BILINEAR).convert('RGBA')
    if f in (4,7):
        opening=opening.transform(opening.size,Image.Transform.AFFINE,(1,0,6 if f==4 else -3,0,1,0))
    fade_in=min(1,max(0,(f-1)/7))
    opening.putalpha(opening.getchannel('A').point(lambda a: int(a*fade_in)))
    return Image.alpha_composite(bg,opening).convert('RGB')

@lru_cache(maxsize=4)
def feature_layers(name):
    card=CARDS[name]
    backdrop=ImageEnhance.Brightness(source(*card['background'])).enhance(.045)
    overlay=Image.new('RGBA',(1920,1080));d=ImageDraw.Draw(overlay)
    headline=ImageFont.truetype('/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf',172)
    subtitle=ImageFont.truetype(str(ROOT/'fonts/VT323-Regular.ttf'),44)
    cream=(237,231,213,255)
    d.line((914,241,1006,241),fill=(164,49,39,255),width=5)
    for line,y in zip(card['lines'],[433,619]):
        bounds=d.textbbox((0,0),line,font=headline)
        assert bounds[2]-bounds[0]<1540, (name,line,bounds)
        d.text((962,y+2),line,font=headline,fill=(85,27,24,200),anchor='mm')
        d.text((960,y),line,font=headline,fill=cream,anchor='mm')
    bounds=d.textbbox((0,0),card['sub'],font=subtitle)
    assert bounds[2]-bounds[0]<1560, (name,bounds)
    d.text((960,770),card['sub'],font=subtitle,fill=(190,190,177,255),anchor='mm')
    return backdrop,overlay

def feature_frame(name,f,total=45):
    backdrop,overlay=feature_layers(name)
    overlay=overlay.copy()
    opacity=min(1.,(f+1)/5.,(total-f)/4.)
    overlay.putalpha(overlay.getchannel('A').point(lambda a:round(a*opacity)))
    if f in (1,3):
        overlay=overlay.transform(overlay.size,Image.Transform.AFFINE,(1,0,5 if f==1 else -2,0,1,0))
    rng=np.random.default_rng(8000+f)
    grain=rng.integers(0,7,(270,480),dtype=np.uint8)
    noise=Image.fromarray(grain).resize((1920,1080),Image.Resampling.BILINEAR)
    bg=np.clip(np.asarray(backdrop,dtype=np.int16)+np.asarray(noise)[:,:,None],0,255).astype(np.uint8)
    return Image.alpha_composite(Image.fromarray(bg).convert('RGBA'),overlay).convert('RGB')

def video():
    layer=title_layer()
    title_frame(40,layer).save(OUT/'title-review.jpg',quality=95)
    intro_frame(30,layer).save(OUT/'intro-review.jpg',quality=95)
    for name in CARDS: feature_frame(name,30).save(OUT/f'{name}.jpg',quality=95)
    cmd=[FF,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pixel_format','rgb24',
         '-video_size','1920x1080','-framerate',str(FPS),'-i','-','-an','-c:v','libx264',
         '-preset','medium','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart',
         '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709',str(BUILD/'picture.mp4')]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    contact=[]
    for name,start,end,src_start,src_end in EDIT:
        print('EDIT',name,f'{start/FPS:.2f}–{end/FPS:.2f}',flush=True)
        for frame in range(start,end):
            local=frame-start
            sf=min(src_end-1,src_start+int(local*(src_end-src_start)/(end-start)))
            if name=='title': im=title_frame(sf,layer)
            elif name=='intro': im=intro_frame(local,layer)
            elif name in CARDS: im=feature_frame(name,local,end-start)
            else: im=source(name,sf)
            if local==(end-start)//2:
                thumb=im.copy();thumb.thumbnail((384,216));contact.append((name,start,thumb))
            proc.stdin.write(im.tobytes())
    proc.stdin.close()
    if proc.wait(): raise RuntimeError('Picture encode failed')
    sheet=Image.new('RGB',(1536,math.ceil(len(contact)/4)*242),(14,14,14));d=ImageDraw.Draw(sheet)
    for i,(name,start,thumb) in enumerate(contact):
        x=i%4*384;y=i//4*242;sheet.paste(thumb,(x,y));d.text((x+8,y+220),f'{start/FPS:05.2f}  {name}',fill='white')
    sheet.save(OUT/'shot-contact-sheet.jpg',quality=91)

def decode(path, start=0., duration=5., speed=1.):
    cmd=[FF,'-v','error','-ss',str(start),'-i',str(ROOT/path),'-t',str(duration)]
    if speed!=1: cmd+=['-af',f'atempo={speed}']
    cmd+=['-f','f32le','-ac','2','-ar',str(SR),'-']
    r=subprocess.run(cmd,check=True,capture_output=True)
    return np.frombuffer(r.stdout,np.float32).reshape(-1,2).copy()

def normalize(a, db):
    rms=float(np.sqrt(np.mean(a*a)))
    return a*(10**(db/20)/max(rms,1e-5))

def fade(a,attack=.015,release=.12):
    n=min(len(a),int(attack*SR));m=min(len(a),int(release*SR))
    if n: a[:n]*=np.linspace(0,1,n)[:,None]
    if m: a[-m:]*=np.linspace(1,0,m)[:,None]
    return a

def audio():
    length=round(DURATION*SR)
    mix=np.zeros((length,2),np.float32)
    events=[]
    starts={name:start/FPS for name,start,end,ss,se in EDIT}
    durations={name:(end-start)/FPS for name,start,end,ss,se in EDIT}
    cross_audio_at=starts['cross_stay']-(23.3666666667+35/FPS-22.5)
    def add(path,at,duration,db,start=0,speed=1,release=.15,reverse=False):
        a=decode(path,start,duration,speed)
        if reverse:a=a[::-1].copy()
        a=fade(normalize(a,db),.012,release)
        pos=round(at*SR);take=min(len(a),length-pos)
        if take>0: mix[pos:pos+take]+=a[:take]
        events.append(dict(source=str(path),at=round(at,4),source_in=start,duration=duration,target_rms_db=db,speed=speed))
    music=normalize(decode('music/lim9.mp3',60,DURATION),-20)
    tm=np.arange(len(music))/SR
    env=np.interp(tm,[0,.2,3.9,4.2,38,cross_audio_at-.3,cross_audio_at,starts['death']-.2,starts['death'],starts['death']+.15,starts['title'],starts['title']+.25,DURATION-1.2,DURATION],
                  [.18,.28,.28,.8,1,.95,.20,.20,.4,.12,.12,.7,.48,0])
    for name in CARDS:
        at=starts[name];end=at+durations[name]
        env*=np.interp(tm,[at-.10,at+.08,end-.14,end+.08],[1,.48,.48,1])
    mix[:len(music)]+=music*env[:,None]
    events.append(dict(source='music/lim9.mp3',at=0,source_in=60,duration=DURATION,target_rms_db=-20))
    # Cross's original dialogue, synchronized to the in-engine playback clock.
    add('videos/tapes/short_beginning_00.ogv',0,119/FPS,-16)
    add('videos/tapes/short_beginning_02.ogv',cross_audio_at,5.533333,-16,start=22.5)
    # Let the opening warning land clearly over a restrained low-frequency hit.
    n=int(.7*SR);t=np.arange(n)/SR
    opening_hit=(np.sin(2*np.pi*(42*t+1.2*(1-np.exp(-t*18))))*np.exp(-t*8)).astype(np.float32)*.12
    mix[:n]+=np.column_stack((opening_hit,opening_hit))
    for name,start,end,ss,se in EDIT:
        at=start/FPS;dur=(end-start)/FPS
        if name.endswith('_kill') and dur>=2:
            burn=at+(72-ss)/(se-ss)*dur
            idx={'casino_kill':1,'office_kill':4,'school_kill':6,'server_kill':2,'annex_kill':7}[name]
            add(f'sounds/sound-demondeath{idx}.mp3',burn,1.35,-17.5,release=.3)
            add('sounds/sound-walking-carpet.mp3',at,dur,-27,speed=1.3)
        if name.endswith('_traverse') or name=='pool_grand':
            surface='carpet' if name.startswith(('casino','annex')) else 'concrete'
            walk_duration=min(dur,2.7-ss/FPS) if name=='pool_grand' else dur
            add(f'sounds/sound-walking-{surface}.mp3',at,walk_duration,-26)
            add('sounds/sound-breathing.mp3',at,dur,-29,start=3.5)
    for name,idx in [('casino_kill',8),('office_kill',2),('school_kill',7),('server_kill',4),('pool_girl',6)]:
        at=starts[name]
        add(f'sounds/sound-jumpscare{idx}.mp3',at,.65,-23,release=.2)
    add('sounds/supernatural/sn2.mp3',starts['wave'],durations['wave'],-22,start=1)
    add('sounds/supernatural/sn4.mp3',starts['doors'],durations['doors'],-24,start=1)
    add('sounds/sound-water-wade.mp3',starts['annex_flood'],durations['annex_flood'],-23)
    add('sounds/sound-breathing.mp3',starts['annex_flood'],durations['annex_flood'],-29,start=2)
    add('sounds/sound-water-wade.mp3',starts['pool_floaties'],2,-27)
    add('sounds/data-center-ambient.mp3',starts['server_traverse'],3,-28)
    add('build/promo-trailer/audio/portal.wav',starts['portal'],durations['portal'],-24)
    add('build/promo-trailer/audio/shutter.wav',starts['portal']+1,.35,-17,speed=1.4)
    add('sounds/sound-walking-concrete.mp3',starts['portal']+65/FPS,(115-65)/FPS,-26)
    add('sounds/sound-walking-carpet.mp3',starts['portal']+126/FPS,durations['portal']-126/FPS,-26)
    add('sounds/sound-playerdeath3.mp3',starts['death'],2.5,-16,release=.45)
    add('sounds/sound-jumpscare10.mp3',starts['title'],2.6,-20,release=1.0)
    # Original editorial percussion follows the accelerating montage.
    rng=np.random.default_rng(21)
    for at in np.arange(3.9667,cross_audio_at-.2,60/144):
        n=int(.22*SR);t=np.arange(n)/SR
        kick=np.sin(2*np.pi*(48*t+42*.035*(1-np.exp(-t/.035))))*np.exp(-t*21)
        click=rng.standard_normal(n)*np.exp(-t*145)*.06
        a=np.column_stack((kick+click,kick+click)).astype(np.float32)
        a=fade(a,.003,.03)*(.13 if at<starts['card_alive'] else .19)
        if any(starts[name]<=at<starts[name]+durations[name] for name in CARDS):a*=.40
        pos=round(at*SR);mix[pos:pos+n]+=a
    # Each feature card gets a bass punctuation and a short tape-like sweep.
    for i,name in enumerate(CARDS):
        at=starts[name];n=int(.85*SR);t=np.arange(n)/SR
        low=np.sin(2*np.pi*(40*t+2.1*(1-np.exp(-t*15))))*np.exp(-t*5.2)
        air=rng.standard_normal(n)*np.exp(-t*20)*.025
        hit=(low*.17+air).astype(np.float32)
        hit=fade(np.column_stack((hit,hit)),.004,.15)
        pos=round(at*SR);mix[pos:pos+n]+=hit
        events.append(dict(source='Original feature-card bass and tape sweep',at=at,duration=.85))
    # A sub hit anchors the title after the death drops to black.
    n=int(2.7*SR);t=np.arange(n)/SR
    hit=(np.sin(2*np.pi*(36*t+2.5*(1-np.exp(-t*14))))*np.exp(-t*2.4)).astype(np.float32)*.27
    pos=round(starts['title']*SR);mix[pos:pos+n]+=np.column_stack((hit,hit))
    mix[-int(.4*SR):]*=np.linspace(1,0,int(.4*SR))[:,None]
    # Float WAV preserves headroom for the mastering pass.
    subprocess.run([FF,'-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i','-',
                    '-c:a','pcm_f32le',str(BUILD/'mix.wav')],input=mix.tobytes(),check=True)
    (OUT/'audio-edit.json').write_text(json.dumps(events,indent=2))
    master_audio()

def master_audio():
    measure=subprocess.run([FF,'-hide_banner','-i',str(BUILD/'mix.wav'),'-af',
       'loudnorm=I=-14:TP=-1.2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    stats=json.JSONDecoder().raw_decode(measure.stderr[measure.stderr.rfind('{'):])[0]
    (OUT/'loudness-measurement.json').write_text(json.dumps(stats,indent=2))
    filt=(f"loudnorm=I=-14:TP=-1.2:LRA=9:measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
          f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:offset={stats['target_offset']}:linear=true")
    subprocess.run([FF,'-v','error','-y','-i',str(BUILD/'mix.wav'),'-af',filt,'-ar',str(SR),
                    '-c:a','pcm_s24le',str(BUILD/'master.wav')],check=True)

def finish():
    final=OUT/'It_Wants_You_To_Stay_Promo_1080p_v6.mp4'
    subprocess.run([FF,'-v','error','-y','-i',str(BUILD/'picture.mp4'),'-i',str(BUILD/'master.wav'),
        '-map','0:v','-map','1:a','-c:v','libx264','-preset','slow','-crf','18','-maxrate','24M','-bufsize','48M',
        '-pix_fmt','yuv420p','-c:a','aac','-b:a','320k','-t',str(DURATION),'-movflags','+faststart',
        '-metadata','title=It Wants You To Stay — Official Promo Trailer',
        '-metadata','artist=@AIandDesign',str(final)],check=True)
    rows=[]
    for name,start,end,ss,se in EDIT:
        rows.append(dict(shot=name,in_seconds=start/FPS,out_seconds=end/FPS,source_frame_in=ss,source_frame_out=se))
    (OUT/'edit.json').write_text(json.dumps(dict(version=6,fps=30,width=1920,height=1080,duration=DURATION,vhs=True,crt=False,
        enemy_roster_source='ShadowFigures.THEME_WALKER / DARK_ROSTER',camera='native walking controller, 90-degree mouse turns, head bob 1.0, handheld enabled 0.55',
        source_omissions={'portal':dict(raw_frames=[115,116,117,118,119],reason='Editorial cut over source-world flash at native realm handoff; destination fade-in retained')},
        feature_cards={k:dict(headline=' / '.join(v['lines']),description=v['sub'],hold_seconds=1.5) for k,v in CARDS.items()},shots=rows),indent=2))
    print('FINAL',final,flush=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('--audio-only',action='store_true');p.add_argument('--video-only',action='store_true');p.add_argument('--master-only',action='store_true');a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    BUILD.mkdir(parents=True,exist_ok=True)
    if a.master_only:
        master_audio();finish();return
    if not a.audio_only:video()
    if not a.video_only:audio()
    finish()

if __name__=='__main__':main()
