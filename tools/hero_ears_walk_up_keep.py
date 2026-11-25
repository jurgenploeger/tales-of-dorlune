#!/usr/bin/env python3
"""Walk up for the elf: ChatGPT's ears lifted with hero_ears_row.py --band 3 (elf_wu2b_b.png in the scratch folder), then every
row outside the ears' own rows put back to the human walk (its top of head and neck, the user, 2026-11-25) and the human
ear's red inner pixels there given the skin beside them. Writes elf_wu2k_b.png; the row's ears and cut come from it."""
from PIL import Image;import numpy as np
H='/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/'
W=np.asarray(Image.open(H+'hero64_doll_walk_up.png').convert('RGBA')); E=np.asarray(Image.open('elf_wu2b_b.png')).copy()
def red(p): return p[3] and int(p[0])-int(p[1])>60 and p[1]<125 and p[:3].max()>=100
for c in range(8):
    f=W[:,c*64:(c+1)*64]; e=E[:,c*64:(c+1)*64]
    out=(e[...,3]>0)&(f[...,3]==0)
    rows=np.nonzero(out.any(1))[0]; a,b=rows.min(),rows.max()+1      # the ears' rows, plus one under them
    keep=np.ones(64,bool); keep[a:b+1]=False
    e[keep]=f[keep]
    # the human ear's red inside pixels in the kept rows given the skin beside them (their outline stays)
    for y in np.nonzero(keep)[0]:
        for x in range(64):
            if red(e[y,x]) and (x<26 or x>38):
                for dx in ((1,2,3) if x<32 else (-1,-2,-3)):
                    q=e[y,x+dx]
                    if q[3] and q[:3].max()>=100 and not red(q): e[y,x]=q; break
    E[:,c*64:(c+1)*64]=e
Image.fromarray(E).save('elf_wu2k_b.png')
st=np.asarray(Image.open(H+'hero64_elf_up.png').convert('RGBA'))
o=Image.new('RGB',(9*180,2*168),(120,170,90))
for r,src in enumerate((W,E)):
    for c in range(9):
        t=Image.new('RGBA',(64,64),(120,170,90,255)); t.alpha_composite(Image.fromarray(st if c==0 else src[:,(c-1)*64:c*64]))
        o.paste(t.crop((14,10,48,40)).resize((180,158),Image.NEAREST).convert('RGB'),(c*180,r*168+5))
o.save('wu2k_heads.png')
