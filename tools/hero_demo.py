#!/usr/bin/env python3
"""The doll in the game, for the hero sheets' overview: walking a circle on a map, and attacking in battle.

  git fetch --depth=1 --filter=blob:none origin screenshots
  git show origin/screenshots:claude/come-back-features/store_land_explore.png > /tmp/explore.png
  hero_demo.py /tmp/explore.png <out dir>     -> demo_walk.gif, demo_battle.gif

The scene is a HUD-free screenshot at 3x, so the doll goes in at 3 pixels an art pixel (one point each, as the
game draws it), and at 6 in battle (fighters stand twice as big). The battle's backdrop is the map blurred and
shaded as BattleScene.buildGround does; the monster flashes white and is knocked back on the strike."""
import sys, os
import math, numpy as np
from PIL import Image, ImageDraw, ImageFilter
H='/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/'
SPR='/home/user/tales-of-dorlune/art/sprites/'
DIRS=["up","up-right","right","down-right","down","down-left","left","up-left"]
def sheet(anim, n):
    s=Image.open(H+f'hero64_doll_{anim}.png').convert('RGBA')
    return {d:[s.crop((c*64,r*64,(c+1)*64,(r+1)*64)) for c in range(n)] for r,d in enumerate(DIRS)}
walk=sheet('walk',8); idle=sheet('idle',4); attack=sheet('attack',6)
def big(im,k): return im.resize((im.width*k, im.height*k), Image.NEAREST)
def shadow(w,h,alpha=90):
    m=Image.new('L',(w,h),0); ImageDraw.Draw(m).ellipse((0,0,w-1,h-1),fill=alpha)
    s=Image.new('RGBA',(w,h),(20,30,20,0)); s.putalpha(m.filter(ImageFilter.GaussianBlur(2))); return s

# --- walking a circle on the map -------------------------------------------------------------------
scene=Image.open(sys.argv[1]).convert('RGBA')
OUT=sys.argv[2]
X0,Y0,W,Hh=1350,425,560,400
bg=scene.crop((X0,Y0,X0+W,Y0+Hh))
bg.paste(bg.crop((60,0,110,22)),(0,0))      # a scrap of a name label in the corner: sand over it
K=3                                  # the screenshots are at 3x: one art pixel, one point, three pixels
cx,cy,R=190,222,95
steps=72; frames=[]
for i in range(steps):
    t=2*math.pi*i/steps
    x,y=cx+R*math.cos(t), cy+R*0.62*math.sin(t)       # a circle on the ground, squashed as the view is
    dx,dy=-math.sin(t), 0.62*math.cos(t)               # walking round it, clockwise on screen
    ang=math.degrees(math.atan2(dx,-dy))%360           # 0 up, clockwise
    d=DIRS[int(((ang+22.5)%360)//45)]
    f=big(walk[d][i%8],K)
    im=bg.copy()
    sh=shadow(16*K,5*K); im.alpha_composite(sh,(int(x-sh.width/2),int(y-sh.height/2)))
    im.alpha_composite(f,(int(x-32*K),int(y-60*K)))   # feet (row 60) on the path
    frames.append(im.convert('RGB'))
frames[0].save(os.path.join(OUT,'demo_walk.gif'),save_all=True,append_images=frames[1:],duration=83,loop=0,optimize=True)

# --- an attack in battle -------------------------------------------------------------------------
B=scene.crop((900,250,900+1050,250+600)).filter(ImageFilter.GaussianBlur(10))
shade=Image.new('RGBA',B.size,(13,20,51,int(255*0.38))); B=Image.alpha_composite(B,shade)
K2=6                                  # fighters stand twice as big in battle
jelly=Image.open(SPR+'monster_jelly.png').convert('RGBA')
js=K2*48/ max(jelly.size)*0.75
jelly=jelly.resize((int(jelly.width*js),int(jelly.height*js)),Image.NEAREST)
hx,hy=700,470; mx,my=330,470
seq=[('idle',c) for c in range(4)]*2+[('attack',c) for c in range(6)]+[('idle',c) for c in range(4)]
frames=[]
def white(im):
    a=np.array(im); a[...,:3][a[...,3]>0]=255; return Image.fromarray(a)
for j,(anim,c) in enumerate(seq):
    im=B.copy()
    for (x,y,w) in ((mx,my,40),(hx,hy,24)):
        sh=shadow(w*K2//2*2,8*K2,110); im.alpha_composite(sh,(int(x-sh.width/2),int(y-sh.height/2)))
    hit = anim=='attack' and c in (3,4)
    m = white(jelly) if anim=='attack' and c==3 else jelly
    push = -12 if hit else 0
    im.alpha_composite(m,(int(mx-m.width/2+push),int(my-m.height+6)))
    f=big((idle if anim=='idle' else attack)['left'][c],K2)
    im.alpha_composite(f,(int(hx-32*K2),int(hy-60*K2)))
    frames.append(im.convert('RGB'))
dur=[300 if a=='idle' else 110 for a,_ in seq]
frames[0].save(os.path.join(OUT,'demo_battle.gif'),save_all=True,append_images=frames[1:],duration=dur,loop=0,optimize=True)
print('ok', len(frames))
