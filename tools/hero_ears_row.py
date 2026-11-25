#!/usr/bin/env python3
"""Lift the elf's ears off ChatGPT's elf painting of one walk or attack row, frame by frame, as drawn.

  hero_ears_row.py <anim> <direction> <snapped row.png> <tag> <frames>
      -> ears_<tag>.png (save it as docs/ai-sprite-test/heroes/hero64_doll_ears_<anim>_<direction>.png),
         elf_<tag>.png, <tag>_4x.png (the human row, the snap, its ears on the row) and <tag>.gif

The painting is ChatGPT's repaint of the row's picked painting with the ears added (snap it with
hero_snap_walk.py and thin it first). Each frame is lined up with the approved frame by its head
(hero_ears.fit); kept are the pixels by the back of the head (and both sides facing down or up, the far tip past
the face facing down-right; facing up-right the near ear is on the right of the head, the far tip on its left) that differ from the approved frame or lie outside it. No pixel is redrawn: the
user, 2026-11-24, "just use what chatgpt provided"."""
import sys, numpy as np
sys.path.insert(0,'/home/user/tales-of-dorlune/tools')
from PIL import Image
import hero_ears as he
D='/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/'
BAND=None
if '--band' in sys.argv:
    i=sys.argv.index('--band'); BAND=int(sys.argv[i+1]); del sys.argv[i:i+2]
anim,d,snap,tag,n=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4],int(sys.argv[5])
both = d in ('down', 'up'); far_tip = d=='down-right'
behind = d=='up-right'   # the near ear on the right of the head, the far ear's tip past its left
row=np.asarray(Image.open(D+f'hero64_doll_{anim}_{d}.png').convert('RGBA'))
S=np.asarray(Image.open(snap))
lay=np.zeros_like(row); cut=np.zeros_like(row); shifts=[]
for c in range(n):
    f=row[:,c*64:(c+1)*64]; g=S[:,c*64:(c+1)*64]
    dy,dx=he.fit(g,f); shifts.append((dy,dx)); g=np.roll(np.roll(g,-dy,0),-dx,1)
    # the head's edges from the standing view moved onto this frame: from the frame itself, a raised arm passed
    # for the back of the head and the small human ear was left showing (attack right, 2026-11-24)
    ref=he.standing(d); ry,rx=he.fit(f,ref)
    cols=np.nonzero(ref[15:35,:,3].any(0))[0]; left,right=cols.min()+rx,cols.max()+rx
    # facing up, only the head: below it the doll's own neck stays (ChatGPT's, lifted too, came out muddy, the user,
    # 2026-11-25); the neck is the narrowest row a head's height under the frame's top
    last=38
    if d=='up':
        w=f[...,3].astype(bool).sum(1); top=int(np.nonzero(w)[0].min())
        last=min(range(top+12,top+24),key=lambda r:w[r])-2
    for y in range(14,last):
        for x in range(64):
            p,q=g[y,x],f[y,x]
            if not p[3]:
                # facing up, where the elf's head is narrower than the doll's, the doll's pixels go (its wider
                # head and small human ears showed past ChatGPT's, the user, 2026-11-25)
                if d=='up' and q[3] and (x<=left+8 or x>=right-8): cut[y,c*64+x]=(255,0,0,255)
                continue
            diff = q[3]==0 or (p[:3]!=q[:3]).any()
            if behind:
                if (x>=right-8 and diff) or (x<left and q[3]==0): lay[y,c*64+x]=p
            elif x<=left+8 and diff: lay[y,c*64+x]=p                # the ear and the small human ear it covers
            elif both and x>=right-(8 if d=='up' else 6) and diff: lay[y,c*64+x]=p
            elif far_tip and x>right and q[3]==0: lay[y,c*64+x]=p
if BAND is not None:
    # --band N: the doll's own head kept, only a strip N pixels in from each side of it (row by row, from three rows
    # under its top to just above the neck) and what lies outside it taken from ChatGPT's, the doll's pixels in the
    # strip cut where ChatGPT's head is narrower: its small human ears go, and its face, shading and raised arm stay
    # (attack up, the user, 2026-11-25: "use the human animation with just the ears")
    from scipy import ndimage
    lay=np.zeros_like(row); cut=np.zeros_like(row)
    for c in range(n):
        f=row[:,c*64:(c+1)*64]; g=S[:,c*64:(c+1)*64]; dy,dx=shifts[c]; g=np.roll(np.roll(g,-dy,0),-dx,1)
        w=f[...,3].astype(bool).sum(1); top=int(np.nonzero(w)[0].min()); last=min(range(top+12,top+24),key=lambda r:w[r])-2
        m=np.zeros((64,64),bool); k=np.zeros((64,64),bool)
        # the ear tips rise to about the head's top: there only what lies past the head's widest sides (the middle
        # would bring ChatGPT's taller head top in as a cap; from top+3 alone the tips were cut off, the user)
        ext=[np.nonzero(f[y,:,3])[0] for y in range(top,last)]
        L0=min(e.min() for e in ext if len(e)); R0=max(e.max() for e in ext if len(e))
        for y in range(max(top-4,0),top+3):
            for x in range(64):
                if g[y,x,3] and not f[y,x,3] and (x<=L0+BAND or x>=R0-BAND): m[y,x]=True
        for y in range(top+3,last):
            xs=np.nonzero(f[y,:,3])[0]
            if not len(xs): continue
            l,r=xs.min(),xs.max()
            for x in range(64):
                band = x<=l+BAND or x>=r-BAND
                if g[y,x,3] and (f[y,x,3]==0 or (band and (g[y,x,:3]!=f[y,x,:3]).any())): m[y,x]=True
                if band and f[y,x,3] and not g[y,x,3]: k[y,x]=True
        lab,nl=ndimage.label(m,structure=np.ones((3,3)))
        for j in range(1,nl+1):
            if (lab==j).sum()<5: m[lab==j]=False                                  # specks, not ears
        lay[:,c*64:(c+1)*64][m]=g[m]; cut[:,c*64:(c+1)*64][k]=(255,0,0,255)
print('shifts',shifts)
Image.fromarray(lay).save(f'ears_{tag}.png')
if cut[...,3].any(): Image.fromarray(cut).save(f'ears_{tag}_cut.png')  # save as ..._cut.png beside the ears
body=row.copy(); body[cut[...,3]>0]=0
im=Image.fromarray(body); im.alpha_composite(Image.fromarray(lay)); el=np.asarray(im); Image.fromarray(el).save(f'elf_{tag}.png')
st=Image.open(D+('hero64_elf_down.png' if d=='down' else f'hero64_elf_{d}.png')).convert('RGBA')
out=Image.new('RGBA',(64*n,64*3),(120,170,90,255))
out.alpha_composite(Image.fromarray(row),(0,0)); out.alpha_composite(Image.fromarray(S),(0,64)); out.alpha_composite(Image.fromarray(el),(0,128))
out.resize((64*n*4,768),Image.NEAREST).save(f'{tag}_4x.png')
fr=[]
for c in range(n):
    im=Image.new('RGBA',(128,64),(120,170,90,255)); im.alpha_composite(st,(0,0)); im.alpha_composite(Image.fromarray(el[:,c*64:(c+1)*64]),(64,0))
    fr.append(im.convert('RGB').resize((512,256),Image.NEAREST))
fr[0].save(f'{tag}.gif',save_all=True,append_images=fr[1:],duration=110 if anim=='attack' else 83,loop=0)
