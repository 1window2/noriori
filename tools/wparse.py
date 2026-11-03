# -*- coding: utf-8 -*-
# 위키백과 문서 HTML에서 노선도 행과 표를 뽑는다
import re,html
from html.parser import HTMLParser
class N:
    __slots__=('t','a','c','p')
    def __init__(s,t,a,p):s.t=t;s.a=dict(a);s.c=[];s.p=p
VOID={'img','br','hr','meta','link','input','wbr','col'}
class P(HTMLParser):
    def __init__(s):
        super().__init__(convert_charrefs=True);s.root=N('root',[],None);s.cur=s.root
    def handle_starttag(s,t,a):
        n=N(t,a,s.cur);s.cur.c.append(n)
        if t not in VOID:s.cur=n
    def handle_endtag(s,t):
        c=s.cur
        while c is not None and c.t!=t:c=c.p
        if c is not None and c.p is not None:s.cur=c.p
    def handle_data(s,d):s.cur.c.append(d)
def walk(n):
    yield n
    for c in n.c:
        if isinstance(c,N):yield from walk(c)
def text(n,skip=('sup','style','script')):
    o=[]
    for c in n.c:
        if isinstance(c,str):o.append(c)
        elif c.t not in skip:
            if c.t=='br':o.append(' ')
            o.append(text(c,skip))
    return ''.join(o)
def imgs(n):
    return [m for m in walk(n) if m.t=='img' and 'BSicon_' in m.a.get('src','')]
def parse(path):
    p=P();p.feed(open(path,encoding='utf-8').read());return p.root
def parse_text(t):
    p=P();p.feed(t);return p.root
def links(n):
    o=[]
    for m in walk(n):
        if m.t=='a':
            t=m.a.get('title') or ''
            if t and not re.match(r'^(ファイル|File|Help|Wikipedia|テンプレート|Template):',t) and '存在しないページ' not in t and not imgs(m):o.append(t)
    return o
def main_table(root):
    best=None;bc=0
    for t in walk(root):
        if t.t=='table':
            c=len(imgs(t))
            if c>=bc:best=t;bc=c   # innermost tie wins
    return best,bc

def leaf_rows(table):
    out=[]
    for tr in walk(table):
        if tr.t!='tr':continue
        if any(q.t=='tr' for q in walk(tr) if q is not tr):continue
        tds=[c for c in tr.c if isinstance(c,N) and c.t in('td','th')]
        if not tds:continue
        out.append(tds)
    return out
ICON=re.compile(r'BSicon_(.*?)\.svg')
def icon_name(img):
    m=ICON.search(img.a.get('src',''))
    return html.unescape(m.group(1).replace('%2B','+').replace('%40','@').replace('%21','!').replace('%3F','?').replace('%C3%9C','Ü')) if m else None
def direct_rows(table):
    out=[]
    for c in table.c:
        if not isinstance(c,N):continue
        if c.t=='tr':out.append(c)
        elif c.t in('tbody','thead'):
            out+= [q for q in c.c if isinstance(q,N) and q.t=='tr']
    return out
def stack(td):
    st=[]
    for im in imgs(td):
        k=icon_name(im)
        if not k:continue
        st.append((k,im))
    return st
def extract(path,minicons=30,root=None):
    r=root or parse(path)
    tabs=[t for t in walk(r) if t.t=='table' and len(imgs(t))>minicons]
    if not tabs:return [],{}
    mx=max(len(imgs(t)) for t in tabs)
    big=[t for t in tabs if len(imgs(t))>=mx*.85]
    top=big[-1]
    rows=[];src={}
    def add(trs):
        for tr in trs:
            tds=[c for c in tr.c if isinstance(c,N) and c.t in('td','th')]
            nested=[t for td in tds for t in walk(td) if t.t=='table']
            if len(tds)==1 and nested and direct_rows(nested[0]) and len(imgs(nested[0]))>8:
                add(direct_rows(nested[0]));continue
            if not any(imgs(td) for td in tds):
                if len(tds)==1 and text(tds[0]).strip():rows.append({'c':[],'k':'','t':re.sub(r'\s+',' ',text(tds[0])).strip(),'h':1})
                continue
            cells=[]
            ic=[td for td in tds if imgs(td)]
            nest=[td for td in ic if any(t.t=='table' for t in walk(td))]
            if nest:ic=nest[:1]
            elif len(ic)>1:ic=[td for td in ic if not re.search(r'[一-龥ぁ-んァ-ヶ가-힣]',text(td))] or ic
            for td in ic:
                inner=[t for t in walk(td) if t.t=='table']
                if inner:
                    lr=[q for q in walk(inner[0]) if q.t=='td']
                else:lr=[td]
                for c in lr:
                    st=stack(c)
                    for k,im in st:
                        ss=im.a.get('srcset','')
                        m=re.search(r'(\S+)\s+2x',ss)
                        u=(m.group(1) if m else im.a.get('src',''))
                        src[k]=('https:'+u if u.startswith('//') else u).split('?')[0]
                    cells.append([k for k,_ in st])
            def tdtext(td):
                return re.sub(r'\s+',' ',text(td)).strip()
            txt=[x for x in (tdtext(td) for td in tds) if x]
            km='';tx=' '.join(txt)
            m=re.match(r'^((?:\(?[\d]+\.[\d]+\)?\s*)+)(.*)$',tx)
            if m:
                km=m.group(1).strip();tx=m.group(2).strip()
            ln=[x for td in tds if not imgs(td) or len(tds)==1 for x in links(td)]
            rows.append({'c':cells,'k':km,'t':tx,'l':ln})
    add(direct_rows(top))
    return rows,src
