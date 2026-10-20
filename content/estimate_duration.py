import re,sys
for p in sys.argv[1:]:
    body=open(p).read().split('---',2)[2]
    sec=None; st={}
    for l in body.splitlines():
        l=l.strip()
        if l.startswith('## '): sec=l[3:]; st[sec]=[0,0.0]; continue
        if not l or sec is None: continue
        m=re.fullmatch(r'\[pause ([\d.]+)s\]',l)
        if m: st[sec][1]+=float(m.group(1)); continue
        l=re.sub(r'\[\w+\]','',l); st[sec][0]+=len(l.split())
    tot=0
    for k,(w,ps) in st.items():
        t=w/95*60+ps; tot+=t
        print(f"{p.split('/')[-1]:32} {k:8} words={w:4} pauses={ps:5.0f}s est={t:5.0f}s")
    print(f"{'':32} TOTAL est={tot/60:.1f} min\n")
