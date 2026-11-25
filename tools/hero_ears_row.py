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
    for y in range(14,38):
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
