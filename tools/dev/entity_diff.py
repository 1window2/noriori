# 판 사이에 빠진 실체를 찾는다: 역(현행·폐역), 노선(현행·폐선), 계통, 사업자, 열람 전용 노선·역, 묶음, 환승 묶음, 이름.
# 재설계로 지운 것은 사유가 있어야 한다 (data/overrides/removed.json: {"node:n_x": "사유", ...}).
#   python3 -I tools/dev/entity_diff.py snapshot <master.sqlite> <names.sqlite> <out.json>
#   python3 -I tools/dev/entity_diff.py compare <old.json> <master.sqlite> <names.sqlite>
import sys,json,sqlite3,os
def snap(master,names):
    m=sqlite3.connect(f'file:{master}?mode=ro',uri=True);n=sqlite3.connect(f'file:{names}?mode=ro',uri=True)
    q=lambda db,sql:[r for r in db.execute(sql)]
    has=lambda db,t:bool(db.execute("select 1 from sqlite_master where name=?",(t,)).fetchone())
    pub={r[0] for r in q(m,'select id from node_public')} if has(m,'node_public') else {r[0] for r in q(m,'select id from node')}
    stops={r[0] for r in q(m,'select distinct node_id from route_stop where is_stop=1')}
    out=dict(
        node=sorted(pub),
        stop_node=sorted(pub&stops),
        line=sorted(r[0] for r in q(m,'select id from line')),
        route=sorted(r[0] for r in q(m,'select id from route')),
        operator=sorted(r[0] for r in q(m,'select id from operator')),
        archive_line=sorted(r[0] for r in q(m,'select id from archive_line')) if has(m,'archive_line') else [],
        archive_stop=sorted(r[0] for r in q(m,'select id from archive_stop')) if has(m,'archive_stop') else [],
        group=sorted({r[0] for r in q(m,'select group_id from node where group_id is not null')}),
        hub=sorted(r[0] for r in q(m,'select id from hub')),
        line_stops={l:sorted({r[0] for r in q(m,f"select distinct rs.node_id from route_stop rs join route r on r.id=rs.route_id where r.line_id='{l}' and rs.is_stop=1")}) for (l,) in q(m,'select id from line')},
        name=sorted({f'{e}|{i}|{l}|{t}' for e,i,l,t in q(n,'select entity_type,entity_id,lang,text from name')}),
    )
    return out
def main():
    if sys.argv[1]=='snapshot':
        json.dump(snap(sys.argv[2],sys.argv[3]),open(sys.argv[4],'w',encoding='utf-8'),ensure_ascii=False)
        print('저장',sys.argv[4]);return
    old=json.load(open(sys.argv[2],encoding='utf-8'));new=snap(sys.argv[3],sys.argv[4])
    rp=os.path.join(os.path.dirname(__file__),'..','..','data','overrides','removed.json')
    removed=json.load(open(rp,encoding='utf-8')) if os.path.exists(rp) else {}
    bad=0
    for k in ('node','stop_node','line','route','operator','archive_line','archive_stop','group','hub'):
        gone=sorted(set(old[k])-set(new[k]));added=sorted(set(new[k])-set(old[k]))
        unexplained=[x for x in gone if f'{k}:{x}' not in removed and (k!='stop_node' or f'node:{x}' not in removed)]
        bad+=len(unexplained)
        print(f'{k:13} 전 {len(old[k]):6} 뒤 {len(new[k]):6} 빠짐 {len(gone):4} (사유 없음 {len(unexplained)}) 새로 {len(added)}',unexplained[:8])
    # 노선마다 정차역이 빠졌는가 (다른 노드로 옮겨 간 것은 이름으로 본다)
    lost=[]
    for l,ns in old['line_stops'].items():
        now=set(new['line_stops'].get(l,[]))
        for x in ns:
            if x not in now and f'node:{x}' not in removed and f'line_stop:{l}|{x}' not in removed:lost.append(f'{l}|{x}')
    bad+=len(lost);print('노선 정차역 빠짐',len(lost),lost[:10])
    # 이름: 실체가 남아 있는데 이름 행이 사라진 것
    keep={f'{e}|{i}' for e,i,*_ in (x.split('|',3) for x in new['name'])}
    nl=[x for x in sorted(set(old['name'])-set(new['name'])) if '|'.join(x.split('|')[:2]) in keep]
    print('이름 행 바뀜·빠짐',len(nl),nl[:6])
    print('사유 없이 빠진 것',bad)
    sys.exit(1 if bad else 0)
main()
