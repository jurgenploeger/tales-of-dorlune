#!/usr/bin/env python3
"""Walk up for the elf, steadied: painting 2 lifted with hero_ears_row.py --band 3 (elf_wu2b_b.png in the scratch folder)
had its lower head 1 to 3 pixels wider or narrower from frame to frame, so the head hobbled (the user, 2026-11-25); the
rows from the ears' foot to above the neck are taken from one frame (the one closest to the human head) in every frame,
moved with the head, and every skin pixel touching the background gets an outline pixel there. Writes elf_wu2s_b.png."""
from PIL import Image;import numpy as np
H='/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/'
W=np.asarray(Image.open(H+'hero64_doll_walk_up.png').convert('RGBA')); E0=np.asarray(Image.open('elf_wu2b_b.png'))
OUT=np.array([77,41,34,255],np.uint8)
def info(c):
    f=W[:,c*64:(c+1)*64]; e=E0[:,c*64:(c+1)*64]
    w=f[...,3].astype(bool).sum(1); top=int(np.nonzero(w)[0].min()); neck=min(range(top+12,top+24),key=lambda r:w[r])
    cx=int(round(np.nonzero(f[top,:,3])[0].mean()))
    out=(e[...,3]>0)&(f[...,3]==0); b=int(np.nonzero(out.any(1))[0].max())+1
    return f,e,top,neck,cx,b
# the reference: the frame whose lower head (below the ears) is widest, closest to the human's
best=None
for c in range(8):
    f,e,top,neck,cx,b=info(c)
    diff=sum(abs(int(e[y,:,3].astype(bool).sum())-int(f[y,:,3].astype(bool).sum())) for y in range(b,neck-1))
    if best is None or diff<best[0]: best=(diff,c)
rc=best[1]; rf,re,rtop,rneck,rcx,rb=info(rc); print('reference frame',rc+1)
R0=rb-rtop; R1=rneck-2-rtop
E=E0.copy()
for c in range(8):
    f,e,top,neck,cx,b=info(c); e=e.copy()
    dy=top-rtop; dx=cx-rcx
    for yy in range(R0,R1):
        y=top+yy; ry=rtop+yy
        if not (0<=y<64): continue
        xs=np.nonzero(re[ry,:,3])[0]; xs=xs[(xs>rcx-16)&(xs<rcx+16)]
        if not len(xs): continue
        lo,hi=xs.min()-2,xs.max()+2
        for x in range(lo,hi+1):
            X=x+dx
            if 0<=X<64: e[y,X]=re[ry,x]
    # close outline gaps: a skin pixel touching clear gets an outline pixel there
    for y in range(10,40):
        for x in range(1,63):
            if e[y,x,3] and e[y,x,:3].max()>=100:
                for a,bb in ((1,0),(-1,0),(0,1),(0,-1)):
                    if e[y+a,x+bb,3]==0: e[y+a,x+bb]=OUT
    E[:,c*64:(c+1)*64]=e
Image.fromarray(E).save('elf_wu2s_b.png')
for c in range(8):
    f,e0,top,neck,cx,b=info(c); e=E[:,c*64:(c+1)*64]
    print(c+1,[int(e[y,:,3].astype(bool).sum()) for y in range(top,neck)])
st=np.asarray(Image.open(H+'hero64_elf_up.png').convert('RGBA'))
o=Image.new('RGB',(9*180,2*168),(120,170,90))
for r,src in enumerate((E0,E)):
    for c in range(9):
        t=Image.new('RGBA',(64,64),(120,170,90,255)); t.alpha_composite(Image.fromarray(st if c==0 else src[:,(c-1)*64:c*64]))
        o.paste(t.crop((14,10,48,40)).resize((180,158),Image.NEAREST).convert('RGB'),(c*180,r*168+5))
o.save('wu2s_heads.png')
fr=[]
for c in range(8):
    im=Image.new('RGBA',(128,64),(120,170,90,255)); im.alpha_composite(Image.fromarray(E0[:,c*64:(c+1)*64]),(0,0)); im.alpha_composite(Image.fromarray(E[:,c*64:(c+1)*64]),(64,0))
    fr.append(im.convert('RGB').resize((512,256),Image.NEAREST))
fr[0].save('wu2s.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
