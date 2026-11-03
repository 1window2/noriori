# build/master.sqlite를 읽어 scratch에 변조 판을 만든다. 프로젝트는 건드리지 않는다.
import sqlite3,shutil,sys,os
out=sys.argv[1];SRC=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','build','master.sqlite')
def pack(name,fn):
    p=os.path.join(out,name+'.sqlite');shutil.copy(SRC,p);os.chmod(p,0o644)
    d=sqlite3.connect(p);fn(d);d.commit();d.execute('VACUUM');d.close()
    print('만듦',name)
def split(d):
    """new-station: 札沼線 百合が原~篠路 사이에 新駅. edge 은퇴, 두 edge로 분할 (§2.10 split-edge)"""
    r='r_sassho_line'
    seq,node=d.execute("select seq,node_id from route_stop where route_id=? and seq=5",(r,)).fetchone()
    nxt=d.execute("select node_id from route_stop where route_id=? and seq=6",(r,)).fetchone()[0]
    e,=d.execute("select id from edge where (from_node=? and to_node=?) or (from_node=? and to_node=?)",(node,nxt,nxt,node)).fetchone()
    km,=d.execute("select km from edge_km where edge_id=?",(e,)).fetchone()
    a,b=round(km*.4,1),round(km-round(km*.4,1),1)
    d.execute("insert into node values('n_newstation',(select kind from node where id=?),'g_newstation',(select pref from node where id=?),null)",(node,node))
    d.execute("insert into station_group values('g_newstation')")
    for new,x,y,k in (('e_900001',node,'n_newstation',a),('e_900002','n_newstation',nxt,b)):
        d.execute("insert into edge select ?,?,?,seed_line,route_only,geometry_quality from edge where id=?",(new,x,y,e))
        d.execute("insert into edge_km values(?,?)",(new,k))
        d.execute("insert into edge_life select ?,valid_from,valid_from_lo,valid_from_hi,valid_to,valid_to_lo,valid_to_hi,status,last_service,legal_abolition,close_reason from edge_life where edge_id=?",(new,e))
        d.execute("insert into edge_attr select ?,line_id,operator_id,lineage_id,carryover_group,denominator_class,valid_from,valid_from_lo,valid_from_hi,valid_to,valid_to_lo,valid_to_hi from edge_attr where edge_id=?",(new,e))
        d.execute("insert into edge_pref select ?,pref,?,approx from edge_pref where edge_id=?",(new,k,e))
        for ky,c,_,_,cl,f,t,ce in d.execute("select * from denominator_unit where edge_id=?",(e,)).fetchall():
            d.execute("insert into denominator_unit values(?,?,?,?,?,?,?,?)",(ky.split(':')[0]+':'+new,c,new,k,cl,f,t,ce))
    s,=d.execute("select seq from route_edge where route_id=? and edge_id=?",(r,e)).fetchone()
    d.execute("update route_edge set seq=seq+1 where route_id=? and seq>?",(r,s))
    d.execute("update route_edge set edge_id='e_900001' where route_id=? and edge_id=?",(r,e))
    d.execute("insert into route_edge values(?,?, 'e_900002')",(r,s+1))
    for t in('edge','edge_km','edge_life','edge_attr','edge_pref','denominator_unit'):
        d.execute(f"delete from {t} where {'id' if t=='edge' else 'edge_id'}=?",(e,))
    d.execute("update route_stop set seq=seq+1 where route_id=? and seq>?",(r,seq))
    d.execute("insert into route_stop select route_id,?,?,km_cum,is_stop,is_extension,'2027-03-13','2027-03-13','2027-03-13','ongoing','9999-12-31','9999-12-31' from route_stop where route_id=? and seq=?",(seq+1,'n_newstation',r,seq))
def relocate(d):
    """이설일 정정: 吾妻線 이설 2014-10-01 → 2014-10-02 (하루 정정)"""
    for e in ('e_001464','e_001465'):
        d.execute("update edge_life set valid_from='2014-10-02',valid_from_lo='2014-10-02',valid_from_hi='2014-10-02' where edge_id=?",(e,))
        d.execute("update edge_attr set valid_from='2014-10-02',valid_from_lo='2014-10-02',valid_from_hi='2014-10-02' where edge_id=?",(e,))
    for e in ('e_001471','e_001472'):
        d.execute("update edge_life set valid_to='2014-10-02',valid_to_lo='2014-10-02',valid_to_hi='2014-10-02' where edge_id=?",(e,))
        d.execute("update edge_attr set valid_to='2014-10-02',valid_to_lo='2014-10-02',valid_to_hi='2014-10-02' where edge_id=?",(e,))
def reverse(d):
    """닫힌 계통의 역 순서 반전: 기점 정의를 바로잡는 정정"""
    for r in ('r_oedo_line','r_sapporo_streetcar','r_port_island_line'):
        m,=d.execute("select max(seq) from route_stop where route_id=?",(r,)).fetchone()
        d.execute("update route_stop set seq=?-seq where route_id=?",(m,r))
def closure(d):
    """폐지일 정정: 日高本線 鵜苫~様似 구간을 1년 앞당김"""
    es=[e for e, in d.execute("select edge_id from edge_life where close_reason is not null and edge_id in (select edge_id from route_edge where route_id='r_hidaka_main_line')")]
    print('  日高本線 폐지 구간 edge',len(es),d.execute("select valid_to from edge_life where edge_id=?",(es[0],)).fetchone())
    for e in es:
        d.execute("update edge_life set valid_to='2019-04-01',valid_to_lo='2019-04-01',valid_to_hi='2019-04-01' where edge_id=?",(e,))
        d.execute("update edge_attr set valid_to='2019-04-01',valid_to_lo='2019-04-01',valid_to_hi='2019-04-01' where edge_id=?",(e,))
def tomb(d):
    """역 하나가 계통에서 사라짐(잘못 만든 역의 묘비): 札沼線 百合が原 양쪽을 한 edge로 합침"""
    r='r_sassho_line'
    a=d.execute("select node_id from route_stop where route_id=? and seq=4",(r,)).fetchone()[0]
    b=d.execute("select node_id from route_stop where route_id=? and seq=5",(r,)).fetchone()[0]
    c=d.execute("select node_id from route_stop where route_id=? and seq=6",(r,)).fetchone()[0]
    e1,=d.execute("select id from edge where (from_node=? and to_node=?) or (from_node=? and to_node=?)",(a,b,b,a)).fetchone()
    e2,=d.execute("select id from edge where (from_node=? and to_node=?) or (from_node=? and to_node=?)",(b,c,c,b)).fetchone()
    k=d.execute("select sum(km) from edge_km where edge_id in (?,?)",(e1,e2)).fetchone()[0]
    d.execute("update edge set from_node=?,to_node=? where id=?",(a,c,e1));d.execute("update edge_km set km=? where edge_id=?",(k,e1))
    for t,col in (('route_edge','edge_id'),('edge_km','edge_id'),('edge_life','edge_id'),('edge_attr','edge_id'),('edge_pref','edge_id'),('denominator_unit','edge_id'),('edge','id')):
        d.execute(f"delete from {t} where {col}=?",(e2,))
    d.execute("delete from route_stop where route_id=? and node_id=?",(r,b));d.execute("delete from node where id=?",(b,))
    d.execute("insert into id_redirect values('node',?,null,'[]','2027')",(b,))
def transfer(d):
    """병행 재래선 이관: 札沼線 전 구간을 2026-10-01부터 새 3섹 노선으로. 같은 사슬, 새 carryover_group"""
    es=[e for e, in d.execute("select edge_id from route_edge where route_id='r_sassho_line'")]
    d.execute("insert into line select 'l_newsector',* from (select type,rule_class from line limit 0)") if False else None
    cols=[r[1] for r in d.execute("pragma table_info(line)")]
    d.execute(f"insert into line({','.join(cols)}) select 'l_newsector',{','.join(cols[1:])} from line where id='l_sassho_line'")
    rc=[r[1] for r in d.execute("pragma table_info(route)")]
    d.execute(f"insert into route({','.join(rc)}) select 'r_newsector','l_newsector',{','.join(rc[2:])} from route where id='r_sassho_line'")
    d.execute("insert into route_edge select 'r_newsector',seq,edge_id from route_edge where route_id='r_sassho_line'")
    d.execute("insert into route_stop select 'r_newsector',seq,node_id,km_cum,is_stop,is_extension,'2026-10-01','2026-10-01','2026-10-01','ongoing','9999-12-31','9999-12-31' from route_stop where route_id='r_sassho_line'")
    for e in es:
        d.execute("insert into edge_attr select edge_id,'l_newsector','o_newsector',lineage_id,'c_newsector',denominator_class,'2026-10-01','2026-10-01','2026-10-01','ongoing','9999-12-31','9999-12-31' from edge_attr where edge_id=? and line_id='l_sassho_line'",(e,))
        d.execute("update edge_attr set valid_to='2026-10-01',valid_to_lo='2026-10-01',valid_to_hi='2026-10-01' where edge_id=? and line_id='l_sassho_line'",(e,))
        d.execute("update denominator_unit set valid_to='2026-10-01' where edge_id=? and carryover='off'",(e,))
        for ky,km in d.execute("select unit_key,km from denominator_unit where edge_id=? and carryover='off'",(e,)).fetchall():
            d.execute("insert into denominator_unit values(?,'off',?,?,'normal','2026-10-01','ongoing','certain')",('c_newsector:'+e,e,km))
    d.execute("update route_stop set valid_to='2026-10-01',valid_to_lo='2026-10-01',valid_to_hi='2026-10-01' where route_id='r_sassho_line'")
for n,f in (('split',split),('relocate',relocate),('reverse',reverse),('closure',closure),('tomb',tomb),('transfer',transfer)):pack(n,f)
