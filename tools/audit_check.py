# -*- coding: utf-8 -*-
# 감사 지적이 고쳐졌는지 DB에서 다시 본다
import sqlite3,json,sys,collections
d=sqlite3.connect('build/master.sqlite');n=sqlite3.connect('build/names.sqlite')
d.row_factory=sqlite3.Row
nm={}
for r in n.execute("select entity_type,entity_id,text from name where lang='ja'"):nm.setdefault((r[0],r[1]),r[2])
def lines(q):
    return [(r[0],r[1]) for r in n.execute("select entity_id,text from name where entity_type='line' and lang='ja' and text like ?",('%'+q+'%',))]
print('== C1')
for q in ['伊勢線','平坂','西遠','白棚','尾小屋','大夕張','尺別','片上','上野懸垂']:
    L=lines(q)
    print(q,[(a,b,d.execute('select count(*) from edge_attr where line_id=?',(a,)).fetchone()[0],d.execute("select count(*) from closed_section where line_id=?",(a,)).fetchone()[0]) for a,b in L])
print('archive',[r[0] for r in n.execute("select text from name where entity_type='archive' and lang='ja' and (text like '%平坂%' or text like '%西遠%' or text like '%白棚%' or text like '%尾小屋%' or text like '%伊勢線%' or text like '%尺別%')")])
print('== C2')
g=json.load(open('data/candidates/gen_report.json',encoding='utf-8'))
T=g['transfers'];print(len(T))
for x in T:
    if any(k in x[0] for k in('池北','高千穂','能登','七尾','神岡','三木','牟岐','北条','樽見','明知','若桜','信楽')):print(x)
print('== C3')
for q in ['石巻線','花輪線','阿佐東線','ゆりかもめ','耶馬渓線']:
    for a,b in lines(q):
        print(q,[dict(x) for x in d.execute("select id,closed,role from route where line_id=?",(a,))][:3])
print('self loop',d.execute('select count(*) from edge where from_node=to_node').fetchone()[0])
print('main 없는 노선',d.execute("select count(*) from line l where not exists(select 1 from route r where r.line_id=l.id and r.role='main')").fetchone()[0])
print('closed route',[ (r['id']) for r in d.execute("select id from route where closed=1")])
def km(rid):
    x=d.execute('select max(km_cum) from route_stop where route_id=?',(rid,)).fetchone()[0];return x
for r in ('r_joban_line','r_agatsuma_line','r_yamanote_line','r_osaka_loop_line'):print(r,km(r))
print('== C4')
def node(q):
    return [r[1] for r in n.execute("select text,entity_id from name where entity_type='node' and lang='ja' and text=?",(q,))]
for q in ['代々木','岐阜','高島町','楓','斜里','知床斜里','野村','西脇市','金津','芦原温泉','長野原','長野原草津口']:
    for i in node(q):
        print(q,i,[dict(x) for x in d.execute('select route_id,km_cum,valid_from,valid_to from route_stop where node_id=? limit 3',(i,))])
print('== D1')
for a,b in lines('富山港線'):print(a,b)
for a,b in lines('富山港線'):
    print(a,[dict(x) for x in d.execute('select operator_id,valid_from,valid_to,count(*) c from edge_attr where line_id=? group by operator_id,valid_from,valid_to',(a,))])
print('== D4')
for a,b in lines('札沼線')+lines('気仙沼線')+lines('大船渡線')+lines('日田彦山線')+lines('海峡線'):
    print(b,[dict(x) for x in d.execute("select from_node,to_node,km,abolished,last_service from closed_section where line_id=?",(a,))][:3])
print('== D5',tuple(d.execute('select count(*),count(distinct line_id||from_node||to_node) from closed_section').fetchone()))
print('== D10',[dict(x) for x in d.execute("select distinct operator_id from edge_attr where line_id in (select id from line where id like '%10050%')")][:5])
for q in ['松田連絡線']:
    for a,b in lines(q):print(a,b,[dict(x) for x in d.execute('select distinct operator_id from edge_attr where line_id=?',(a,))])
print('== D11')
for q in ['揖斐線','美濃町線','天王寺支線','長岡線','三井芦別']:
    for a,b in lines(q):print(b,a,[dict(x) for x in d.execute('select valid_from,valid_to,count(*) c from edge_attr where line_id=? group by 1,2',(a,))][:4])
print('== D12')
for q in ['夕張線','岐阜市内','田神','永平寺','北九州線']:
    print(q,lines(q),[r[0] for r in n.execute("select text from name where entity_type='archive' and lang='ja' and text like ?",('%'+q+'%',))])
print('== 이름')
print('station 표기',n.execute("select count(*) from name where lang='en' and (lower(text) like '%station%' or text like '%staton%')").fetchone())
print('미노오',n.execute("select count(*) from name where lang='ko' and text like '미노오%'").fetchone())
print('~에키',n.execute("select count(*) from name where lang='ko' and entity_type='node' and text like '%에키'").fetchone(),[r[0] for r in n.execute("select text from name where lang='ko' and entity_type='node' and text like '%에키' limit 8")])
print('코사쿠',[r[0] for r in n.execute("select text from name where lang='ko' and entity_type='line' and text like '%코사쿠%'")])
print('카모츠',[r[0] for r in n.execute("select text from name where lang='ko' and entity_type='line' and text like '%카모츠%'")])
print('렌라쿠',[r[0] for r in n.execute("select text from name where lang='ko' and entity_type='line' and text like '%렌라쿠%'")])
print('type',[dict(x) for x in d.execute("select id,type from line where id like 'l_hieizan%' or id like '%tappishakou%'")])
