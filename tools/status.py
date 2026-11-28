# -*- coding: utf-8 -*-
# docs/db-status.md를 빌드 결과에서 만든다. 수치는 손으로 고치지 않는다
import sys,os,json,sqlite3,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
# 원천 대조 값(audit_ext, gen_report, n_totals)은 로컬에만 있다. 없으면 그 줄을 빼고 알린다
OUT=sys.argv[1] if len(sys.argv)>1 else os.path.join(ROOT,'docs','db-status.md')
def opt(p):
    return json.load(open(p,encoding='utf-8')) if os.path.exists(p) else None
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'))
n=sqlite3.connect(os.path.join(BUILD,'names.sqlite'))
rep=json.load(open(os.path.join(BUILD,'report.json'),encoding='utf-8'))
TABLES={r_[0] for r_ in m.execute("select name from sqlite_master where type='table'")}
ver=json.load(open(os.path.join(BUILD,'verify.json'),encoding='utf-8'))
au=opt(os.path.join(BUILD,'audit_ext.json'))
gen=opt(os.path.join(CAND,'gen_report.json'))
nt=opt(os.path.join(CAND,'n_totals.json'))
def one(q):return m.execute(q).fetchone()[0]
def km(x):return f'{x:,.1f}'
okm=rep['operator_km']
cat=dict(m.execute('select id,category from operator'))
STAGE=[('JR 홋카이도',lambda o:o=='o_jr_hokkaido' or o=='o_1'),
       ('JR 나머지 5사',lambda o:cat.get(o)=='jr' and o not in('o_jr_hokkaido','o_1')),
       ('대형·준대형 사철',lambda o:cat.get(o) in('major_private','semi_major_private')),
       ('공영',lambda o:cat.get(o)=='public'),
       ('그 밖의 사철·3섹',lambda o:cat.get(o)=='general_private'),
       ('모노레일·신교통',lambda o:cat.get(o) in('monorail','agt')),
       ('강삭',lambda o:cat.get(o)=='cable')]
rows=[]
for name,f in STAGE:
    ks=[o for o in okm if f(o)]
    rows.append((name,len(ks),sum(okm[o] for o in ks)))
L=collections.Counter()
for t,c in m.execute('select type,count(*) from line group by 1'):L[t]=c
closed=one("select count(*) from line l where not exists(select 1 from edge_attr a where a.line_id=l.id and a.valid_to='ongoing')")
est=n.execute("select count(*) from name where lang='ko' and source='estimated'").fetchone()[0]
wk=ver.get('위키 km 대조')
nm_=ver.get('현행 역 이름')
pos=ver['위치']
# 행은 (선 유무, 출처, 수)다. 출처 열이 생기기 전 판은 (선 유무, 수)였다
geo=collections.Counter()
for row in ver['선형 있는 edge']:geo[row[0] or 'none']+=row[-1]
curgeo=rep.get('geometry_rate')
last=one('select count(*) from edge_life where last_service is not null')
reason=dict(m.execute('select close_reason,count(*) from edge_life where close_reason is not null group by 1'))
out=f"""# noriori DB 현황

`python3 -I tools/status.py`가 빌드 결과로 만든 문서입니다. 기준일 {rep['today']}. 설계는 [DESIGN.md](DESIGN.md), 감사와 조사 기록은 [research/](research/)에 있습니다.

## 규모

| 항목 | 값 |
|---|---|
| 사업자 | {rep['operators']} |
| 노선 | {rep['lines']} (현행 {rep['lines']-closed}, 현행 멤버십 없음 {closed}) |
| 계통 | {rep['routes']} |
| 노드 | {rep['nodes']} (공개 {rep['public_nodes']}) |
| edge | {rep['edges']} |
| 사건 | {rep['events']} |
| 계통 위 역 행 | {rep['route_stop']} |
| 이어짐·분기·환승 링크 | {rep['route_link']} (이어짐 {one("select count(*) from route_link where kind='continue'")}, 분기 {one("select count(*) from route_link where kind='branch'")}, 환승 {one("select count(*) from route_link where kind='transfer'")}) |
| 환승 묶음 | {rep['hubs']} |
| 분기 지점 | {rep['junctions']} |
| 열람 전용 | 역 {one('select count(*) from archive_stop')}, 노선 {one('select count(*) from archive_line')} |

## 구축 단계별 현행 km

| 묶음 | 사업자 | 현행 km |
|---|---|---|
"""
for a,b,c in rows:out+=f'| {a} | {b} | {km(c)} |\n'
out+=f"""| **합계** | {sum(r[1] for r in rows)} | **{km(sum(r[2] for r in rows))}** |

노선 종류: 일반 철도 {L['rail']}, 노면전차 {L['tram']}, 모노레일 {L['monorail']}, 신교통 {L['agt']}, 강삭 {L['cable']}, 트롤리 {L['trolley']}.

## 분모

| 기준 | km |
|---|---|
| 현행 | {km(rep['denominators']['current:on'])} |
| 역대, 승계 켬 | {km(rep['denominators']['alltime:on'])} |
| 역대, 승계 끔 | {km(rep['denominators']['alltime:off'])} |
"""
for y in ('1950','1960','1970','1980','1987','2000','2010','2020'):
    if y in ver['연도별 분모']:out+=f"| {y}년 | {km(ver['연도별 분모'][y])} |\n"
bad={k:v for k,v in (nt or {}).items() if abs(okm.get(k,0)-v)>.15}
SKIP='원천이 없어 건너뜀'
out+=f"""
## 검증

| 검사 | 결과 |
|---|---|
| 사업자별 현행 km, 노리츠부시 표 대조 | {f'{len(nt)}개 중 불일치 {len(bad)}' if nt else SKIP} |
| 컴파일 구조 검사 오류 | {sum(rep['errors'].values()) if rep['errors'] else 0} |
| 해결 못 한 시드 항목 | {len(gen['pending']) if gen else SKIP} |
| 계통 km 경고 | {f"{len((rep.get('warnings') or {}).get('route_km',[]))}건 (폐선 계통, 이관 뒤 구간의 km를 현행값으로 쓰면서 생긴 0.5km 이내 차이)" if nt else SKIP} |
| 역 간격, 위키 노선도 대조 | {f"{wk['pairs']}쌍 중 {wk['ok']}쌍 일치 ({wk['rate']*100:.1f}%, 0.25km 기준)" if wk else SKIP} |
| 현행 역 이름, station_database 대조 | {f"우리 {nm_['db']}, 원자료 {nm_['sd']}, 공통 {nm_['both']}" if nm_ else SKIP} |
| JR→타사 이관 | {f"{len(gen['transfers'])}건" if gen else SKIP} |
| 오늘자 이웃 역 쌍, 노리츠부시 표 대조 | {f"{au['오늘 이웃 쌍, DB에만'].get('ok')}쌍 일치, 표에만 있는 {au['오늘 이웃 쌍, 표에만']['n']}쌍은 화물·연락선·기간 한정 별선" if au else SKIP} |

감사 결과와 항목별 처리는 [research/](research/)의 회차별 문서에 있습니다. 규칙 검사는 `tools/audit_db.py`, 원자료 전수 대조는 `tools/audit_ext.py`입니다. 역 개업일과 폐지일은 역 문서의 `{{{{駅情報}}}}`를 우선으로 씁니다.

## 위치와 선형

| 항목 | 값 |
|---|---|
| 역 위치 정밀 | {pos.get('precise',0)} |
| 역 위치 근사 (좌표 보간) | {pos.get('approx',0)} |
| 역 위치 없음 | {pos.get('none',0)} |
| 선형 있는 edge | {geo.get('precise',0)} / {rep['edges']} |
| 폐지 구간 가운데 지도에 선이 있는 것 | {one('select sum(map_visible) from closed_section')} / {one('select count(*) from closed_section')} |
| 위치 미확인 구간 표식(선이 없는 폐지 구간, §7.3) | {one('select count(*) from map_marker')} |
| 노선 지도 표시 / 기록 가능 (coverage, §2.11) | {one("select count(*) from coverage where grade='지도 표시'") if 'coverage' in TABLES else '-'} / {one("select count(*) from coverage where grade!='지도 표시'") if 'coverage' in TABLES else '-'} |

선형은 N02 2005~2024판에서 만들고, N02에 없는 구간은 OSM 선형을 `rail-osm.pmtiles`로 따로 냅니다. 위 수는 N02 선형만 셉니다.

## 날짜

| 항목 | 값 |
|---|---|
| 개업일 없는 구간 행 | {ver['날짜 없는 개업 edge']} / {rep['attr']} (대부분 옛 사철) |
| 폐지일 없는 폐역 | {ver['날짜 없는 폐역']} / {ver['폐역']} |
| 기준일 전 여객 종료 edge | {ver['기준일 이전 폐지 edge']} (여객 영업은 끝났지만 법적 폐지가 기준일 뒤라 수록) |
| 마지막 운행일이 따로 있는 edge | {last} |
| 폐지 사유 | 폐지 {reason.get('abolished',0)}, BRT {reason.get('brt',0)}, 정기 영업 없음 {reason.get('no_regular_service',0)}, 이설 {reason.get('relocated',0)} |

## 사람이 정한 값 (`data/overrides/`)

| 파일 | 내용 |
|---|---|
| `lines_ko.json`, `lines_kana.json` | 원자료 이름과 공식 노선명이 다른 노선의 한글 이름과 읽기 |
| `kana.json`, `kana_est.json` | 역 읽기. `kana_est.json`의 일부는 한자로 추정한 값이고 한글 이름 출처가 `estimated`로 표시됩니다 ({est}건) |
| `operators_ko.json`, `names_ko.json` | 사업자와 개별 역의 한글 이름 |
| `services.json` | 운행 계통 {one('select count(*) from service')}개 |
| `old_hand.json`, `old_history.json` | 문서에서 옮긴 옛 노선과 구간별 이력 |

코드 안의 표: 3섹 개명 대응(`RENAME`), BRT 첫날(`BRTDAY`), 재해 뒤 마지막 운행일(`SVC`), 앞선 사업자(`OPHIST`), 열람 전용 폐지일(`ARCH_CLOSE`).

## 알려진 한계

- **폐선 선형**: N02와 OSM 어느 쪽에서도 길이가 맞는 경로를 찾지 못한 폐선 구간은 선이 없습니다. OSM 선형은 ODbL이라 `rail-osm.pmtiles`로 따로 냅니다.
- **배경 지도**: 앱에 넣는 기본 배경(`base.pmtiles`)은 일본 윤곽과 도도부현 경계뿐입니다. 자세한 배경은 인터넷이 있을 때 OpenFreeMap을 씁니다.
- **`manifest.json`**: 파일 해시와 ed25519 서명(`manifest.json.sig`)이 있습니다. 서명은 공개 판(태그)에만 로컬에서 붙이고(`tools/release_pack.sh`, ARCHITECTURE §4.5), 이 빌드처럼 서명하지 않은 개발판은 앱이 그대로 씁니다. 최소 앱 버전은 아직 없습니다.
- **도도부현 경계 km**: 근사값입니다.
- **운행 계통**: {one('select count(*) from service')}개만 수록했습니다.
- **열람 전용 폐선**: 역 목록·순서·km를 확정하지 못한 노선은 열람 전용이라 기록할 수 없습니다.
- **나무위키**: 한글 이름은 나무위키 표제어 표기를 출처로 씁니다. 표제어 표기만 사실로 취급하고 출처를 표기합니다.
- **1950년 이전 역 개업일**: 일부는 신호장·화물 개설일이 남아 있습니다. 탑승 기준일 전이라 기록과 통계에는 영향이 없고 연도 표시만 다를 수 있습니다.
- **구간 km 이력**: `edge_km`은 구간당 한 값입니다. 3섹으로 넘어간 구간은 국철 시기 표의 km와 역 사이가 0.2~1km 다를 수 있습니다 (노선 합계는 같음). 승계 끔 역대 분모가 조금 달라집니다.
- **역명 이력**: 역 문서 연혁에서 자동으로 뽑았습니다 ({n.execute("select count(*) from name where valid_to is not null").fetchone()[0]}행). 사철 문서 일부는 빠졌습니다. 한글 표기가 없는 옛 이름은 현행 한글로 보입니다.
- **불통 이력**: 지금 끊긴 구간 {one("select count(distinct edge_id) from edge_life where status='suspended' and valid_to='ongoing'")}개 edge와 동일본 대지진, 2010년대 호우 등 주요 장기 불통만 넣었습니다. 몇 달 이내의 불통은 없습니다.
- **기준일 뒤 폐지인데 열람 전용**: {one("select count(*) from archive_line where closed>='1950-01-01'")}개 노선은 km를 못 구해 기록할 수 없습니다.

## 다시 만들기

```bash
bash tools/all.sh
python3 -I tools/verify.py
python3 -I tools/audit_db.py
python3 -I tools/audit_ext.py
python3 -I tools/status.py
```
"""
os.makedirs(os.path.dirname(os.path.abspath(OUT)),exist_ok=True)
open(OUT,'w',encoding='utf-8').write(out)
print(rows,len(bad))
