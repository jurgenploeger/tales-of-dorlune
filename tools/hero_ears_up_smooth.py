#!/usr/bin/env python3
"""Walk and attack facing up for the elf: the human head as it is, the idle ears (hero_ears.view('up')) laid on each
frame as the idle does, and the human ear bumps below them smoothed into the head edge (the user, 2026-11-25:
"reuse the head shape of the human attack, and just have the elf ears"). Writes up_smooth_<anim>.png in the current
directory; the ears layer and cut are taken from it as hero64_doll_ears_<anim>_up(.png, _cut.png)."""
import sys; sys.path.insert(0,'/home/user/tales-of-dorlune/tools')
from PIL import Image;import numpy as np;import hero_ears as he
H='/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/'
OUT=np.array([77,41,34,255],np.uint8)
def red(p): return p[3] and int(p[0])-int(p[1])>60 and p[1]<125 and p[:3].max()>=100
def dark(p): return p[3] and p[:3].max()<100
def smooth(e,f):
    """e: elf frame (human + elf ears), f: human frame. Smooths the human ear bumps on each side, below the elf ear."""
    e=e.copy(); fixed=[]
    w=f[...,3].astype(bool).sum(1); top=int(np.nonzero(w)[0].min()); neck=min(range(top+12,top+24),key=lambda r:w[r])
    cx=int(round(np.nonzero(f[top,:,3])[0].mean()))
    for side in (-1,1):
        rows=[y for y in range(top+8,neck) if any(red(f[y,x]) for x in (range(0,cx-6) if side<0 else range(cx+6,64)))]
        if not rows: continue
        a,b=min(rows)-2,max(rows)+1
        def edge(y):  # outermost opaque pixel of the human frame on this side
            xs=np.nonzero(f[y,:,3])[0]; xs=xs[xs<cx] if side<0 else xs[xs>cx]
            return (xs.min() if side<0 else xs.max()) if len(xs) else None
        ea,eb=edge(a),edge(b)
        for y in range(a+1,b):
            want=int(round(ea+(eb-ea)*(y-a)/(b-a)))
            xs=range(0,cx) if side<0 else range(cx,64)
            for x in xs:
                beyond = x<want if side<0 else x>want
                if beyond and f[y,x,3] and not (e[y,x,3] and not (e[y,x]==f[y,x]).all()): e[y,x]=0; fixed.append((y,x))
            if not dark(e[y,want]): e[y,want]=OUT; fixed.append((y,want))
            # inside the new edge: no outline, no ear reds; take the skin two pixels further in
            for k in range(1,4):
                x=want-side*k
                if dark(e[y,x]) or red(e[y,x]):
                    src=e[y,want-side*(k+2)]
                    if not dark(src) and not red(src): e[y,x]=src; fixed.append((y,x))
    return e,fixed
if __name__=='__main__':
    ref,ear,gone=he.view('up')
    out=Image.new('RGB',(8*204,2*204),(255,255,255))
    for r,(anim,n) in enumerate((('walk',8),('attack',6))):
        D=np.asarray(Image.open(H+f'hero64_doll_{anim}_up.png').convert('RGBA'))
        res=np.zeros_like(D)
        for c in range(n):
            f=D[:,c*64:(c+1)*64]; el=he.wear(f,ear,he.fit(f,ref),ref)
            el,fx=smooth(el,f); res[:,c*64:(c+1)*64]=el; print(anim,c+1,len(fx))
            t=Image.new('RGBA',(64,64),(120,170,90,255)); t.alpha_composite(Image.fromarray(el))
            out.paste(t.crop((14,10,48,44)).resize((204,204),Image.NEAREST).convert('RGB'),(c*204,r*204))
        Image.fromarray(res).save(f'up_smooth_{anim}.png')
    out.save('up_smooth.png')
