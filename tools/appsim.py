#!/usr/bin/env python3
"""noriori 앱 동작 시뮬레이션과 시나리오 검증.

앱 코드가 아직 없으므로, 앱이 master.sqlite / names.sqlite 로 할 일을
파이썬과 SQL로 직접 흉내 낸다. DB는 읽기 전용(immutable)으로 열고 ATTACH 한다.

    python3 appsim.py                 # 시나리오 전체 + 전수 점검 + 스키마 비교
    python3 appsim.py --json out.json # 결과를 JSON으로도 저장
    python3 appsim.py --no-sweep      # 전수 점검 생략
    python3 appsim.py --master M --names N   # 다른 빌드로 실행

경로를 주지 않으면 build/의 DB를 쓴다.
기간은 [valid_from, valid_to) 반열림 구간으로 해석한다 (JNR→JR이 1987-04-01로 맞물림).
"""
import argparse
import collections
import heapq
import json
import os
import random
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRATCH = os.path.dirname(HERE)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import AS_OF  # noqa: E402

# 판의 기준일. 시험의 "오늘"은 판과 같이 움직인다
TODAY = AS_OF
FLOOR = "1950-01-01"   # §4.6 기준일
MAXD = "9999-12-31"


# ---------------------------------------------------------------- 날짜 ----
def edtf_range(v):
    """EDTF → (lo, hi). None은 (None, None), ongoing은 MAXD."""
    if v is None:
        return (None, None)
    if v == "ongoing":
        return (MAXD, MAXD)
    # 그 사이 어느 날인지 모르는 범위 [A..B] (lib.lohi와 같다)
    m = re.fullmatch(r"\[(.*)\.\.(.*)\]", v)
    if m:
        return (edtf_range(m[1])[0] if m[1] else "0000-01-01", edtf_range(m[2])[1] if m[2] else MAXD)
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", v)
    if m:
        return (v, v)
    m = re.fullmatch(r"(\d{4})-(\d{2})-XX", v)
    if m:
        y, mo = int(m[1]), int(m[2])
        last = [31, 29 if (y % 4 == 0 and (y % 100 or y % 400 == 0)) else 28, 31, 30, 31, 30,
                31, 31, 30, 31, 30, 31][mo - 1]
        return (f"{y:04d}-{mo:02d}-01", f"{y:04d}-{mo:02d}-{last:02d}")
    m = re.fullmatch(r"(\d{4})-XX-XX", v)
    if m:
        return (f"{m[1]}-01-01", f"{m[1]}-12-31")
    m = re.fullmatch(r"(\d{3})X-XX-XX", v)
    if m:
        return (f"{m[1]}0-01-01", f"{m[1]}9-12-31")
    m = re.fullmatch(r"(\d{2})XX-XX-XX", v)
    if m:
        return (f"{m[1]}00-01-01", f"{m[1]}99-12-31")
    raise ValueError(f"EDTF 해석 불가: {v!r}")


def state_on(d, f_lo, f_hi, t_lo, t_hi):
    """날짜 d(EDTF)가 [from, to) 기간에 대해 어떤 상태인가.
    범위 날짜는 겹치면 탈 수 있고, 다 들어가야 yes (§5.4).
    yes/maybe/before/after. d가 None이면 unknown."""
    if d is None:
        return "unknown"
    lo, hi = edtf_range(d)
    if f_lo is not None and hi < f_lo:
        return "before"
    if t_hi is not None and lo >= t_hi:
        return "after"
    if f_lo is None:
        return "maybe"                 # 개업일 모름: 하한 없음
    if lo < (f_hi or f_lo):
        return "maybe"
    if t_lo is None:
        return "maybe"
    if hi >= t_lo:
        return "maybe"
    return "yes"


def normalize_date(d):
    """§4.6: 1950-01-01 이전 날짜는 날짜 모름. 범위가 기준일에 걸쳐도 같다."""
    if d is None:
        return None
    if edtf_range(d)[0] < FLOOR:
        return None
    return d


def overlaps_year(y, f_lo, t_hi):
    """Y년 중 하루라도 겹치는가 (범위의 넓은 쪽 기준)."""
    a, b = f"{y}-01-01", f"{y + 1}-01-01"
    lo = f_lo if f_lo is not None else "0000-01-01"
    hi = t_hi if t_hi is not None else MAXD
    return lo < b and hi > a


def year_certain(y, valid_from, valid_to):
    """Y년에 확실히 영업했는가 (§5.4). 애매하면 분모·분자에서 빼고 판정 불가로 센다.
    폐지 연도만 아는 구간은 그해에 영업한 것으로 친다. 컴파일과 따로 명세에서 옮긴 판정이다."""
    f_lo, f_hi = edtf_range(valid_from)
    t_lo, t_hi = edtf_range(valid_to)
    if not overlaps_year(y, f_lo, t_hi):
        return False
    return f_hi is not None and f_hi < f"{y + 1}-01-01" and t_lo is not None and t_lo >= f"{y}-01-01"


# ------------------------------------------------------------------ DB ----
class App:
    """앱의 데이터 계층에 해당. 앱처럼 master에 names를 ATTACH."""

    def edge_between(self, a, b):
        """두 역 사이의 edge. edge 번호는 역 하나만 끼워도 밀리므로 시험은 번호를 쓰지 않는다"""
        rows = self.db.execute("SELECT id FROM edge WHERE (from_node=? AND to_node=?) OR (from_node=? AND to_node=?)", (a, b, b, a)).fetchall()
        assert len(rows) == 1, (a, b, rows)
        return rows[0][0]

    def __init__(self, master=None, names=None, today=TODAY):
        master = master or os.path.join(SCRATCH, "build", "master.sqlite")
        names = names or os.path.join(SCRATCH, "build", "names.sqlite")
        self.today = today
        self.db = sqlite3.connect(f"file:{master}?mode=ro&immutable=1", uri=True)
        self.db.execute(f"ATTACH DATABASE 'file:{names}?mode=ro&immutable=1' AS nm")
        self.db.row_factory = sqlite3.Row
        self.routes = {r["id"]: dict(r) for r in self.db.execute("SELECT * FROM route")}
        for r in self.routes.values():
            r["via_nodes"] = json.loads(r["via_nodes"] or "[]")
            r["extend_to"] = json.loads(r["extend_to"] or "[]")
        self.line_routes = collections.defaultdict(list)
        for r in self.routes.values():
            self.line_routes[r["line_id"]].append(r["id"])
        self._attrs = collections.defaultdict(list)
        for r in self.db.execute("SELECT * FROM edge_attr"):
            self._attrs[r["edge_id"]].append(dict(r))
        self._life = collections.defaultdict(list)
        for r in self.db.execute("SELECT * FROM edge_life"):
            self._life[r["edge_id"]].append(dict(r))
        self.edges = {r["id"]: dict(r) for r in self.db.execute("SELECT * FROM edge")}
        self.km = {r["edge_id"]: r["km"] for r in self.db.execute("SELECT * FROM edge_km")}
        # 승계 끔 단위는 3섹 전환 때 다시 잰 구간을 국철 시대 km로 센다 (DESIGN §2.9 E)
        self.era = {(r["line_id"], r["edge_id"]): r["km"] for r in self.db.execute("SELECT * FROM edge_km_era")}
        self._edge_routes = collections.defaultdict(list)
        self._route_edges = collections.defaultdict(list)
        for r in self.db.execute("SELECT route_id,seq,edge_id FROM route_edge ORDER BY route_id,seq"):
            self._edge_routes[r["edge_id"]].append(r["route_id"])
            self._route_edges[r["route_id"]].append((r["seq"], r["edge_id"]))
        self._stops = collections.defaultdict(list)
        self._picks = collections.defaultdict(list)      # 선택기 행 (extend_to 포함)
        # 정차 기간 사이에 서지 않던 기간 (여름 임시역 등, stop_dates.json 여러 기간). 앱 inStopGap과 같다
        self._stop_gaps = collections.defaultdict(list)
        if self.db.execute("SELECT 1 FROM sqlite_master WHERE name='route_stop_gap'").fetchone():
            for r in self.db.execute("SELECT * FROM route_stop_gap"):
                self._stop_gaps[(r["route_id"], r["seq"])].append((r["gap_from_hi"], r["gap_to_lo"]))
        for r in self.db.execute("SELECT * FROM route_stop ORDER BY route_id,seq"):
            self._picks[r["route_id"]].append(dict(r))
            if not r["is_extension"]:
                self._stops[r["route_id"]].append(dict(r))
        # 한 방향 운행 칸과 한 방향 정차 (DESIGN §8). 앱 Network.passable·stopDirectionOf와 같다
        self._one_way = collections.defaultdict(list)
        self._one_way_routes = set()
        if self.db.execute("SELECT 1 FROM sqlite_master WHERE name='edge_one_way'").fetchone():
            for r in self.db.execute("SELECT * FROM edge_one_way"):
                self._one_way[(r["route_id"], r["edge_id"])].append(dict(r))
                self._one_way_routes.add(r["route_id"])
        self._stop_direction = collections.defaultdict(list)
        if self.db.execute("SELECT 1 FROM sqlite_master WHERE name='stop_direction'").fetchone():
            for r in self.db.execute("SELECT * FROM stop_direction"):
                self._stop_direction[(r["route_id"], r["node_id"])].append(dict(r))
        self.public = {r[0] for r in self.db.execute("SELECT id FROM node_public")}
        self.node_kind = {r[0]: r[1] for r in self.db.execute("SELECT id,kind FROM node")}
        self.units = {}
        for r in self.db.execute("SELECT * FROM denominator_unit"):
            self.units[(r["unit_key"], r["carryover"])] = dict(r)

    # ------------ 이름 (§14.2) -------------
    def name(self, node, line_id=None, date=None, lang="ja"):
        """노선 고유 + 날짜 > 노선 고유 > 기본 + 날짜 > 기본."""
        rows = self.db.execute(
            "SELECT text,line_id,valid_from,valid_to FROM nm.name "
            "WHERE entity_type='node' AND entity_id=? AND lang=?", (node, lang)).fetchall()
        best, rank = None, 9
        for r in rows:
            dated = r["valid_from"] is not None or (r["valid_to"] not in (None, "ongoing"))
            if r["line_id"] is not None and r["line_id"] != line_id:
                continue
            if dated:
                if date is None:
                    continue
                f = edtf_range(r["valid_from"])[0]
                t = edtf_range(r["valid_to"])[1]
                if (f and date < f) or (t and date >= t):
                    continue
            lv = (0 if dated else 1) if r["line_id"] else (2 if dated else 3)
            if lv < rank:
                best, rank = r["text"], lv
        return best

    def line_name(self, line_id, lang="ja"):
        r = self.db.execute("SELECT text FROM nm.name WHERE entity_type='line' AND entity_id=? AND lang=?",
                            (line_id, lang)).fetchone()
        return r[0] if r else None

    def find_node(self, route_id, text, lang="ja"):
        """화면의 역 이름으로 이 계통의 노드를 찾는다."""
        out = []
        for s in self._stops[route_id]:
            if any(self.name(s["node_id"], self.routes[route_id]["line_id"], None, lg) == text
                   for lg in (lang,)):
                out.append(s["node_id"])
            elif self.name(s["node_id"], None, None, lang) == text:
                out.append(s["node_id"])
        seen = []
        for n in out:
            if n not in seen:
                seen.append(n)
        return seen

    # ------------ 선로 상태 -------------
    def life_on(self, edge, d):
        """edge_life 판정. open/suspended/closed/before/maybe/unknown + 행."""
        rows = self._life[edge]
        if d is None:
            return "unknown", None
        best = None
        seen = []
        for r in rows:
            st = state_on(d, r["valid_from_lo"], r["valid_from_hi"], r["valid_to_lo"], r["valid_to_hi"])
            seen.append(st)
            if st in ("yes", "maybe"):
                res = r["status"] if st == "yes" else "maybe_" + r["status"]
                if best is None or st == "yes":
                    best = (res, r)
        if best:
            return best
        if all(s == "before" for s in seen):
            return "before", None
        return "closed", None

    def attrs_of(self, edge, line_id):
        return [a for a in self._attrs[edge] if a["line_id"] == line_id]

    def attr_on(self, edge, line_id, d, follow_lineage=True):
        """그날의 (노선, edge) 멤버십. follow_lineage면 같은 사슬의 다른 노선까지 본다(§8).
        반환 (행, 판정)."""
        mine = self.attrs_of(edge, line_id)
        lgs = {a["lineage_id"] for a in mine}
        rows = self._attrs[edge] if follow_lineage else mine
        hit = None
        for a in rows:
            if a["lineage_id"] not in lgs:
                continue
            st = state_on(d, a["valid_from_lo"], a["valid_from_hi"], a["valid_to_lo"], a["valid_to_hi"])
            if st == "yes":
                return a, "yes"
            if st == "maybe":
                hit = (a, "maybe")
        return hit if hit else (None, "no")

    def line_on(self, edge, line, d):
        """그날의 노선. 이관 날짜에 걸친 범위 날짜면 입력한 노선을 유지한다 (§2.8 J)."""
        if not d:
            return line
        attr, st = self.attr_on(edge, line, d)
        if attr is None:
            return line
        if st == "yes":
            return attr["line_id"]
        mine = any(
            state_on(d, a["valid_from_lo"], a["valid_from_hi"], a["valid_to_lo"], a["valid_to_hi"]) in ("yes", "maybe")
            for a in self.attrs_of(edge, line))
        return line if mine else attr["line_id"]

    def edge_usable(self, route_id, edge, d):
        """이 계통으로 d에 탈 수 있는 edge인가. (판정, 사유)"""
        line = self.routes[route_id]["line_id"]
        if d is None:
            return "ok", None
        life, _ = self.life_on(edge, d)
        attr, ast = self.attr_on(edge, line, d)
        if life == "suspended":
            return "suspended", life
        if life == "maybe_suspended":
            return "maybe", life
        if life in ("before", "closed"):
            return "no", life
        if attr is None:
            return "no", "no-membership"
        if life.startswith("maybe") or ast == "maybe":
            return "maybe", "range"
        return "ok", None

    # ------------ 1. 역 선택기 -------------
    def route_edges(self, route_id):
        """route_edge → 무향 간선 목록. route_edge.seq는 route_stop.seq와 맞지 않을 수 있어 그래프로 다룬다."""
        out = []
        for seq, e in self._route_edges[route_id]:
            ed = self.edges[e]
            out.append((seq, e, ed["from_node"], ed["to_node"]))
        return out

    def picker(self, route_id, date=None, include_hidden=False):
        """그날 고를 수 있는 역 목록. node_public + is_stop + 기간.
        각 행: seq,node,name,km_cum,km_on_date,state,selectable,links"""
        d = normalize_date(date)
        line = self.routes[route_id]["line_id"]
        link_rows = collections.defaultdict(list)
        for r in self.db.execute("SELECT * FROM route_link WHERE route_id=? ORDER BY seq", (route_id,)):
            link_rows[r["seq"]].append(dict(r))
        # 인접 edge
        adj = collections.defaultdict(list)
        for _, e, a, b in self.route_edges(route_id):
            adj[a].append(e)
            adj[b].append(e)
        kmd = self.km_axis(route_id, d)
        rows = []
        for s in self._picks[route_id]:
            if not include_hidden:
                if not s["is_stop"] and not s["is_extension"]:
                    continue
                if s["node_id"] not in self.public:
                    continue
            st = state_on(d, s["valid_from_lo"], s["valid_from_hi"], s["valid_to_lo"], s["valid_to_hi"])
            # 선로 상태
            line_states = [self.edge_usable(route_id, e, d)[0] for e in adj[s["node_id"]]]
            if s["is_extension"] and d is not None:
                state, sel = ("open", True) if st in ("yes", "maybe") else ("closed", False)
            elif d is None:
                state, sel = "unknown", True
            elif st == "before":
                state, sel = "before_open", False
            elif self.in_stop_gap(d, s):
                state, sel = "closed", False
            elif st == "after":
                state, sel = "closed", False
            elif "ok" in line_states and st == "yes":
                state, sel = "open", True
            elif "ok" in line_states or "maybe" in line_states:
                state, sel = "maybe", True
            elif "suspended" in line_states:
                state, sel = "suspended", False
            elif adj[s["node_id"]] and all(x == "no" for x in line_states):
                state, sel = "line_closed", False
            else:
                state, sel = "no_edge", False
            links = []
            for r in link_rows[s["seq"]]:
                lf = edtf_range(r["valid_from"])[0]
                lt = edtf_range(r["valid_to"])[1]
                if d is None or ((lf is None or lf <= d) and (lt is None or d < lt)):
                    links.append({k: r[k] for k in ("kind", "other_line_id", "other_route_id", "side",
                                                     "at_edge", "other_node", "flow")})
            rows.append(dict(seq=s["seq"], node=s["node_id"],
                             name=self.name(s["node_id"], line, d), km_cum=s["km_cum"],
                             km_on_date=kmd.get(s["seq"]), state=state, selectable=sel, links=links,
                             is_extension=s["is_extension"]))
        return rows

    def km_axis(self, route_id, d):
        """그날 선로망으로 계산한 누적 km. seq→km. 끊겨서 못 구하면 해당 seq 없음."""
        stops = self._stops[route_id]
        cands = collections.defaultdict(list)
        for _, e, a, b in self.route_edges(route_id):
            cands[frozenset((a, b))].append(e)
        out, cum = {}, 0.0
        if not stops:
            return out
        out[stops[0]["seq"]] = 0.0
        # 옛 자리 노드(역 이전)는 새 자리 역과 km 순으로 섞여 있다. 바로 다음 역과 칸이 없으면 세 칸 안의 역으로 잇는다 (S1과 같은 규칙)
        i = 0
        while i < len(stops) - 1:
            p = stops[i]
            got = None
            for usable in ((True, False) if d is not None else (False,)):
                for j in range(i + 1, min(i + 4, len(stops))):
                    es = cands.get(frozenset((p["node_id"], stops[j]["node_id"])), [])
                    if usable:
                        es = [e for e in es if self.edge_usable(route_id, e, d)[0] in ("ok", "maybe", "suspended")]
                    if es:
                        got = (j, es)
                        break
                if got:
                    break
            if not got:
                return out
            j, es = got
            # 날짜 모름이면 현행 쪽(마지막 행)을 택하지 않고 route_edge 앞쪽 값
            cum += self.km[es[0]]
            out[stops[j]["seq"]] = round(cum, 1)
            i = j
        return out

    # ------------ 한 방향 (DESIGN §8) -------------
    @staticmethod
    def _covers_all(cover, life):
        """cover 기간들을 이으면 life의 처음부터 끝까지를 모두 덮는가. 범위로 적힌 끝은 좁은 쪽으로 본다."""
        start = min(r["valid_from_lo"] or "0000-01-01" for r in life)
        end = max(r["valid_to_hi"] or MAXD for r in life)
        spans = sorted((r["valid_from_hi"] or r["valid_from_lo"] or "0000-01-01", r["valid_to_lo"] or r["valid_to_hi"] or MAXD) for r in cover)
        reached = start
        for f, t in spans:
            if f > reached:
                return False
            if t > reached:
                reached = t
            if reached >= end:
                return True
        return reached >= end

    def passable(self, route_id, edge, x, y, d):
        rows = self._one_way.get((route_id, edge))
        if not rows:
            return True
        against = [r for r in rows if r["from_node"] != x or r["to_node"] != y]
        if not against:
            return True
        if d is not None:
            return not any(state_on(d, r["valid_from_lo"], r["valid_from_hi"], r["valid_to_lo"], r["valid_to_hi"]) == "yes" for r in against)
        life = self._life.get(edge) or []
        if not life:
            return True
        return not self._covers_all(against, life)

    def stop_direction_of(self, route_id, node, d):
        rows = self._stop_direction.get((route_id, node))
        if not rows:
            return None
        if d is not None:
            return next((r for r in rows if state_on(d, r["valid_from_lo"], r["valid_from_hi"], r["valid_to_lo"], r["valid_to_hi"]) == "yes"), None)
        life = [s for s in self._stops[route_id] if s["node_id"] == node and s["is_stop"]]
        if not life:
            return None
        for direction in ("seq_up", "seq_down"):
            same = [r for r in rows if r["direction"] == direction]
            if same and self._covers_all(same, life):
                return same[0]
        return None

    def seq_direction(self, route_id, a, b):
        nodes = [s["node_id"] for s in self._stops[route_id]]
        fa = nodes.index(a) if a in nodes else -1
        fb = nodes.index(b) if b in nodes else -1
        return "seq_up" if fb > fa else "seq_down"

    def _refuses_at(self, route_id, n, direction, d, departing):
        r = self.stop_direction_of(route_id, n, d)
        if r is None:
            return False
        use = r["use"] if "use" in r.keys() else None
        return r["direction"] != direction or (departing and use == "alight") or (not departing and use == "board")

    def _refuses(self, route_id, a, b, direction, d):
        return self._refuses_at(route_id, a, direction, d, True) or self._refuses_at(route_id, b, direction, d, False)

    def _shortest_path(self, a, b, edges, pass_=None):
        """길이(km)가 가장 짧은 길. 앱 _shortestPath와 같다."""
        g = collections.defaultdict(list)
        for e, x, y in edges:
            g[x].append((y, e))
            g[y].append((x, e))
        if a == b or a not in g or b not in g:
            return None
        best = {a: 0}
        back = {}
        done = set()
        heap = [(0, 0, a)]
        tick = 0
        while heap:
            c, _, n = heapq.heappop(heap)
            if n in done or c > best.get(n, float("inf")):
                continue
            if n == b:
                break
            done.add(n)
            for m, e in g[n]:
                if m in done or (pass_ and not pass_(e, n, m)):
                    continue
                cost = c + round(self.km[e] * 1000)
                if cost >= best.get(m, float("inf")):
                    continue
                best[m] = cost
                back[m] = (n, e, m)
                tick += 1
                heapq.heappush(heap, (cost, tick, m))
        if b not in back:
            return None
        out = []
        at = b
        while at != a:
            out.append(back[at])
            at = back[at][0]
        return out[::-1]

    # ------------ 2. 탑승 펼치기 -------------
    def _simple_paths(self, route_id, a, b, edges, limit=64, pass_=None):
        """무향 다중 그래프에서 a→b 단순 경로 전부."""
        g = collections.defaultdict(list)
        for e, x, y in edges:
            g[x].append((y, e))
            g[y].append((x, e))
        res = []
        sys.setrecursionlimit(20000)

        def dfs(n, seen, path):
            if len(res) >= limit:
                return
            if n == b and path:
                res.append(list(path))
                return
            for m, e in g[n]:
                if pass_ and not pass_(e, n, m):
                    continue
                if m in seen:
                    continue
                seen.add(m)
                path.append((n, e, m))
                dfs(m, seen, path)
                path.pop()
                seen.discard(m)

        dfs(a, {a}, [])
        return res

    def seq_of(self, route_id, node):
        return [s["seq"] for s in self._stops[route_id] if s["node_id"] == node]

    def ring_nodes(self, route_id):
        """계통 그래프의 2-core(고리). 꼬리(올가미의 放射部)를 떼어 낸다."""
        adj = collections.defaultdict(set)
        for _, _, x, y in self.route_edges(route_id):
            adj[x].add(y)
            adj[y].add(x)
        alive = set(adj)
        changed = True
        while changed:
            changed = False
            for n in list(alive):
                if len(adj[n] & alive) < 2:
                    alive.discard(n)
                    changed = True
        return alive

    def path_direction(self, route_id, path):
        """경로가 route_stop 순서로 위(seq_up)로 도는가 아래(seq_down)로 도는가.
        올가미는 고리 위의 첫 hop으로 판정한다."""
        stops = self._stops[route_id]
        nxt = collections.defaultdict(set)
        for p, q in zip(stops, stops[1:]):
            nxt[p["node_id"]].add(q["node_id"])
        if self.routes[route_id]["from_node"] == self.routes[route_id]["to_node"]:
            nxt[stops[-1]["node_id"]].add(stops[0]["node_id"])
        ring = self.ring_nodes(route_id)
        hop = next(((n, m) for n, _, m in path if n in ring and m in ring), (path[0][0], path[0][2]))
        return "seq_up" if hop[1] in nxt[hop[0]] else "seq_down"

    def lap(self, route_id, start, date=None, direction="seq_up"):
        """닫힌 계통 한 바퀴 (§8 순환 입력, §2.8 G). 올가미는 고리 부분만 돈다."""
        d = normalize_date(date)
        ring = self.ring_nodes(route_id)
        hops = []
        stops = self._stops[route_id]
        cands = collections.defaultdict(list)
        for _, e, x, y in self.route_edges(route_id):
            cands[frozenset((x, y))].append(e)
        pairs = list(zip(stops, stops[1:]))
        for p, q in pairs:
            if p["node_id"] in ring and q["node_id"] in ring:
                es = cands[frozenset((p["node_id"], q["node_id"]))]
                es = [e for e in es if self.edge_usable(route_id, e, d)[0] in ("ok", "maybe")]
                if not es:
                    return dict(status="invalid", reason="not-closed-on-date", km=None)
                hops.append((p["node_id"], es[0], q["node_id"]))
        # 고른 역에서 시작하게 돌리고 방향대로 지나는지 본다 (앱 _fromStart와 같은 순서)
        nodes = [hops[0][0]] + [h[2] for h in hops] if hops else []
        at = nodes.index(start) if start in nodes else 0
        ring_ = bool(nodes) and nodes[0] == nodes[-1]
        if at > 0 and ring_:
            hops = hops[at:] + hops[:at]
        walk = [(x, e, y) for x, e, y in hops] if direction != "seq_down" else [(y, e, x) for x, e, y in reversed(hops)]
        if any(not self.passable(route_id, e, x, y, d) for x, e, y in walk):
            return dict(status="invalid", reason="one-way", km=None)
        es = [e for _, e, _ in walk]
        return dict(status="ok", km=round(sum(self.km[e] for e in es), 1), edges=es, direction=direction)

    def relocation_options(self, route_id, a, b):
        """날짜 모름에서 평행 edge가 갈릴 때 보여 줄 선형 목록(§2.8 D).
        edge 조합 전체가 아니라, 실제로 존재한 시점의 경로만 남긴다."""
        import datetime
        dates = set()
        for _, e, _x, _y in self.route_edges(route_id):
            for r in self._life[e]:
                if r["valid_from_lo"]:
                    dates.add(r["valid_from_lo"])
                if r["valid_to_lo"] and r["valid_to_lo"] < MAXD:
                    dates.add((datetime.date.fromisoformat(r["valid_to_lo"]) - datetime.timedelta(days=1)).isoformat())
        seen = {}
        for d in sorted(dates):
            if d < FLOOR:
                continue
            r = self.expand(route_id, a, b, d, listing=True)
            if r["status"] == "ok":
                seen.setdefault(tuple(sorted(r["edges"])), dict(as_of=d, km=r["km"]))
        return list(seen.values())

    def expand(self, route_id, a, b, date=None, direction=None, as_of=None, resolve_unknown=False, listing=False):
        """(계통, 출발, 도착, 날짜) → edge 목록과 km.

        status: ok / partial / needs_input / invalid / unknown_ref (§2.8 N)
        date가 그날 영업 범위 밖이면 status='invalid' 와 reason을 준다.
        (저장 화면은 §4.6에 따라 날짜 모름으로 내려 다시 호출한다: record 참고)
        """
        if route_id not in self.routes:
            return dict(status="unknown_ref", edges=[], km=None)
        lo, hi = edtf_range(date)
        d = normalize_date(date if lo is not None and lo == hi else (as_of or date))  # 하루로 정해진 날짜가 as_of를 이김
        all_edges = self.route_edges(route_id)
        if a == b:
            if self.routes[route_id]["closed"] and direction in ("seq_up", "seq_down"):
                return self.lap(route_id, a, d, direction)
            return dict(status="invalid", edges=[], km=0.0, reason="same-node")
        use, bad = [], []
        for _, e, x, y in all_edges:
            u, why = self.edge_usable(route_id, e, d)
            if u in ("ok", "maybe"):
                use.append((e, x, y))
            else:
                bad.append((e, u, why))
        pass_ = lambda e, x, y: self.passable(route_id, e, x, y, d)
        paths = self._simple_paths(route_id, a, b, use, pass_=pass_)
        # 한 방향 칸 때문에만 길이 없으면 그 이유로 알린다 (앱과 같음)
        if not paths and self._simple_paths(route_id, a, b, use):
            return dict(status="invalid", edges=[], km=None, d=d, reason="one-way")
        dated = False
        if d is None:
            # 모든 칸이 함께 있던 날이 있는 경로만 남긴다. 그런 경로가 하나도 없으면(옛 자리 갈래와 새 선로 사이 이웃 역) 그대로 둔다
            together = [p for p in paths if self._one_day(p)]
            dated = bool(together)
            paths = together or paths
        if not paths:
            # 어떤 날이라도 경로가 있는가
            anyp = self._simple_paths(route_id, a, b, [(e, x, y) for _, e, x, y in all_edges])
            return dict(status="invalid", edges=[], km=None, d=d,
                        reason="no-path-on-date" if anyp else "no-path-ever",
                        blocked=[x for x in bad][:5], paths_any=len(anyp))
        # 평행 edge(이설)로 갈린 경로와 방향으로 갈린 경로를 구분
        groups = collections.defaultdict(list)
        for p in paths:
            groups[tuple(n for n, _, _ in p)].append(p)
        node_paths = list(groups)
        # 고리는 닫힌 계통에만 있다. 날짜를 모를 때 열린 계통에서 갈린 경로가 저마다 한날에 있던 길이면 옛·새 선형이다 (앱 route_resolver와 같음)
        if len(node_paths) > 1 and not self.routes[route_id]["closed"] and dated:
            groups[node_paths[0]] = [p for np in node_paths for p in groups[np]]
            node_paths = node_paths[:1]
        if len(node_paths) > 1:
            if direction in ("seq_up", "seq_down"):
                node_paths = [np for np in node_paths
                              if self.path_direction(route_id, groups[np][0]) == direction]
                if not node_paths:
                    return dict(status="invalid", edges=[], km=None, reason="no-such-direction")
            elif direction is None and self.routes[route_id]["closed"]:
                node_paths.sort(key=lambda np: sum(self.km[e] for _, e, _ in groups[np][0]))
                node_paths = node_paths[:1]      # 기본은 짧은 쪽 (§8)
            elif resolve_unknown:
                ps = [p for np in node_paths for p in groups[np]]
                common = set(e for _, e, _ in ps[0])
                for p in ps[1:]:
                    common &= set(e for _, e, _ in p)
                return self._result(route_id, [e for _, e, _ in ps[0] if e in common], d, "partial", ps[0])
            else:
                return dict(status="needs_input", edges=[], km=None, reason="ambiguous-path",
                            options=[round(sum(self.km[e] for _, e, _ in groups[np][0]), 1) for np in node_paths])
        closed = self.routes[route_id]["closed"]
        if closed and direction in ("seq_up", "seq_down") and route_id in self._one_way_routes \
                and self.path_direction(route_id, groups[node_paths[0]][0]) != direction:
            return dict(status="invalid", edges=[], km=None, d=d, reason="one-way")
        chosen = groups[node_paths[0]]
        if len(chosen) > 1:
            if resolve_unknown:
                common = set(e for _, e, _ in chosen[0])
                for p in chosen[1:]:
                    common &= set(e for _, e, _ in p)
                es = [e for _, e, _ in chosen[0] if e in common]
                return self._result(route_id, es, d, "partial", chosen[0])
            # 선형 목록을 만드는 중이면 다시 목록을 만들지 않는다 (앱과 같음, 무한 재귀 방지)
            return dict(status="needs_input", edges=[], km=None, reason="relocated-parallel",
                        options=[] if listing else self.relocation_options(route_id, a, b))
        r = self._result(route_id, [e for _, e, _ in chosen[0]], d, "ok", chosen[0])
        way = r["direction"] if closed else self.seq_direction(route_id, a, b)
        if self._refuses(route_id, a, b, way, d):
            return dict(status="invalid", edges=[], km=None, d=d, reason="stop-direction")
        r["around"] = False
        if closed and direction is None and not listing and route_id in self._one_way_routes:
            free = self._simple_paths(route_id, a, b, use)
            if free and min(sum(self.km[e] for _, e, _ in p) for p in free) < sum(self.km[e] for e in r["edges"]) - 1e-9:
                r["around"] = True
        return r

    def _one_day(self, path):
        """경로의 칸이 모두 함께 있던 날이 있는가 (옛 선로와 새 선로를 섞은 고리 경로를 뺀다)"""
        lo, hi = "0000-01-01", MAXD
        for _, e, _ in path:
            rows = self._attrs[e]
            if not rows:
                continue
            lo = max(lo, min(r["valid_from_lo"] or "0000-01-01" for r in rows))
            hi = min(hi, max(r["valid_to_hi"] or MAXD for r in rows))
        return lo < hi

    def _result(self, route_id, es, d, status, path):
        line = self.routes[route_id]["line_id"]
        legs = collections.OrderedDict()
        for e in es:
            legs.setdefault(self.line_on(e, line, d), []).append(e)
        return dict(status=status, edges=es, km=round(sum(self.km[e] for e in es), 1), d=d,
                    nodes=[path[0][0]] + [m for _, _, m in path], line_km={
                        k: round(sum(self.km[e] for e in v), 1) for k, v in legs.items()},
                    route=route_id, legs=legs,
                    direction=self.path_direction(route_id, path) if path else None)

    def record(self, route_id, a, b, date=None, direction=None, as_of=None, resolve_unknown=False):
        """저장 흐름. 그날 경로가 없으면 §4.6에 따라 날짜 모름으로 내려 저장."""
        d = normalize_date(date)
        r = self.expand(route_id, a, b, d, direction, as_of, resolve_unknown)
        demoted = date is not None and d is None
        if r["status"] == "invalid" and d is not None and r.get("reason") in ("no-path-on-date", "not-closed-on-date"):
            r2 = self.expand(route_id, a, b, None, direction, as_of, resolve_unknown)
            r2["demoted_from"] = date
            r2["demote_reason"] = r.get("blocked", [])[:1]
            r = r2
            demoted = True
        r["demoted"] = demoted
        r["saved_date"] = None if demoted else d
        return r

    # ------------ 운행 계통 -------------
    def service_parts(self, service_id, d=None):
        """그날 판의 부분. 앱처럼 날짜와 겹치는 판 중 마지막, 날짜 모름이면 마지막 판이다. 판 표가 없는 옛 판은 부분 전부다."""
        if not self.db.execute("SELECT 1 FROM sqlite_master WHERE name='service_edition'").fetchone():
            return self.db.execute("SELECT * FROM service_part WHERE service_id=? ORDER BY seq", (service_id,)).fetchall()
        eds = self.db.execute("SELECT * FROM service_edition WHERE service_id=? ORDER BY edition", (service_id,)).fetchall()
        pick = eds[-1]["edition"] if eds else 0
        if d is not None:
            lo, hi = edtf_range(d)
            hit = [e["edition"] for e in eds if (e["valid_from_lo"] or "0000-01-01") <= hi and lo < (e["valid_to_hi"] or MAXD)]
            if hit:
                pick = hit[-1]
        return self.db.execute("SELECT * FROM service_part WHERE service_id=? AND edition=? ORDER BY seq", (service_id, pick)).fetchall()

    def service_chain(self, service_id, date=None):
        """service_part를 이어 붙여 (route, node, edge, node) 목록과 끊긴 곳을 돌려준다."""
        d = normalize_date(date)
        parts = self.service_parts(service_id, d)
        hops, gaps = [], []
        prev_end = None
        for p in parts:
            if prev_end is not None and prev_end != p["from_node"]:
                gaps.append((prev_end, p["from_node"]))
            r = self.expand(p["route_id"], p["from_node"], p["to_node"], d)
            if r["status"] not in ("ok",):
                gaps.append((p["route_id"], p["from_node"], p["to_node"], r["status"], r.get("reason")))
                prev_end = p["to_node"]
                continue
            nodes = r["nodes"]
            for i, e in enumerate(r["edges"]):
                hops.append((p["route_id"], nodes[i], e, nodes[i + 1]))
            prev_end = p["to_node"]
        return hops, gaps

    def expand_service(self, service_id, a=None, b=None, date=None, direction="seq_up", full_lap=False):
        hops, gaps = self.service_chain(service_id, date)
        closed = self.db.execute("SELECT closed FROM service WHERE id=?", (service_id,)).fetchone()[0]
        if gaps:
            return dict(status="invalid", reason="service-gap", gaps=gaps, km=None)
        if closed and direction == "seq_down":
            hops = [(r, y, e, x) for r, x, e, y in reversed(hops)]
        if full_lap:
            start = a or hops[0][1]
            idx = next(i for i, h in enumerate(hops) if h[1] == start)
            sel = hops[idx:] + hops[:idx]
        else:
            n = len(hops)
            starts = [i for i, h in enumerate(hops) if h[1] == a]
            if not starts:
                return dict(status="invalid", reason="from-not-in-service", km=None)
            sel = None
            for s in starts:
                rng_ = range(s, s + n) if closed else range(s, n)
                cur = []
                for i in rng_:
                    h = hops[i % n]
                    cur.append(h)
                    if h[3] == b:
                        sel = cur
                        break
                if sel:
                    break
            if not sel:
                return dict(status="invalid", reason="to-not-after-from", km=None)
        legs = collections.OrderedDict()
        for r, x, e, y in sel:
            legs.setdefault(r, []).append(e)
        line_km = collections.OrderedDict()
        for r, es in legs.items():
            ln = self.routes[r]["line_id"]
            line_km[ln] = round(line_km.get(ln, 0) + sum(self.km[e] for e in es), 1)
        return dict(status="ok", km=round(sum(self.km[e] for _, _, e, _ in sel), 1),
                    edges=[e for _, _, e, _ in sel], legs=legs, line_km=line_km,
                    nodes=[sel[0][1]] + [h[3] for h in sel])

    def expand_cross(self, a, b, date=None, routes=None):
        """숨은 노드 경계 자동 분할 (§2.8 F) 흉내: 후보 계통들을 합친 그래프에서 경로를 찾아
        hop별 계통으로 legs를 나눈다. 앱이 service/extend_to 없이 할 수 있는 우회."""
        d = normalize_date(date)
        edges = []
        owner = {}
        for rid in routes:
            for _, e, x, y in self.route_edges(rid):
                u, _ = self.edge_usable(rid, e, d)
                if u in ("ok", "maybe"):
                    edges.append((e, x, y))
                    owner[e] = rid
        # 가장 짧은 길 하나만 쓴다 (앱 _expandCross와 같음, 고리가 많은 그래프의 단순 경로 전수 탐색을 피함)
        p = self._shortest_path(a, b, edges, pass_=lambda e, x, y: self.passable(owner[e], e, x, y, d))
        if p is None:
            return dict(status="invalid", km=None, reason="one-way" if self._shortest_path(a, b, edges) else None)
        pieces = []
        for hop in p:
            if not pieces or owner[pieces[-1][-1][1]] != owner[hop[1]]:
                pieces.append([])
            pieces[-1].append(hop)

        def way(piece):
            rid = owner[piece[0][1]]
            return self.path_direction(rid, piece) if self.routes[rid]["closed"] else self.seq_direction(rid, piece[0][0], piece[-1][2])

        def refused(piece, n, departing):
            return self._refuses_at(owner[piece[0][1]], n, way(piece), d, departing)
        if refused(pieces[0], a, True) or refused(pieces[-1], b, False):
            return dict(status="invalid", km=None, reason="stop-direction")
        legs = collections.OrderedDict()
        for _, e, _x in p:
            legs.setdefault(owner[e], []).append(e)
        return dict(status="ok", km=round(sum(self.km[e] for _, e, _ in p), 1),
                    edges=[e for _, e, _ in p], legs=legs,
                    line_km={self.routes[r]["line_id"]: round(sum(self.km[e] for e in es), 1)
                             for r, es in legs.items()},
                    nodes=[p[0][0]] + [m for _, _, m in p], hidden=[
                        m for _, _, m in p if m not in self.public])

    def expand_any(self, route_id, a, b, date=None):
        """선택기에서 고른 두 역을 펼친다. extend_to 역이면 그 역이 속한 계통으로 leg를 나눈다 (§2.7)."""
        ext = set(self.routes[route_id]["extend_to"])
        if a not in ext and b not in ext:
            return self.expand(route_id, a, b, date)
        here = {n for _, _, x, y in self.route_edges(route_id) for n in (x, y)}
        parents = []
        for n in {a, b} & ext:
            for rid, st in self._stops.items():
                if rid != route_id and any(s["node_id"] == n for s in st) and here & {s["node_id"] for s in st}:
                    parents.append(rid)
        if parents:
            x = self.expand_cross(a, b, date, [route_id] + parents)
            if x["status"] == "ok":
                return x
        # 부모 계통이 숨은 끝을 지나지 않는 연결선: 연장 역까지는 거리 없이 계통 안의 구간만 펼친다 (§2.7)
        stops = self._stops[route_id]
        pick = {s["node_id"]: s["seq"] for s in self._picks[route_id]}
        def anchor(n):
            if n not in ext or any(s["node_id"] == n for s in stops):
                return n
            return stops[0]["node_id"] if pick[n] < stops[0]["seq"] else stops[-1]["node_id"]
        return self.expand(route_id, anchor(a), anchor(b), date)

    # ------------ 3. 완주 계산 -------------
    def unit_of(self, line_id, edge, carryover):
        """기록한 (노선, edge) → 단위 키. 승계 끔의 '탑승일 단위'는 line_id가 이미 탑승일 기준."""
        rows = self.attrs_of(edge, line_id)
        if not rows:
            return None
        a = rows[0]
        return (a["lineage_id"] if carryover == "on" else a["carryover_group"]) + ":" + edge

    def effective_hi(self, ride):
        """§2.8 J 유효 날짜 범위의 끝. created 상한은 입력 날짜가 없는 기록에만 쓴다."""
        ends = self._end_stops(ride)
        date = ride.get("date")
        # 입력한 날에 아직 개업하지 않았거나 정차 기간 사이라 서지 않은 승하차역이 있으면 교집합이 비어 날짜 모름이다
        if date and any(all(((s["valid_from_lo"] or "") > edtf_range(date)[1] and s["valid_from_lo"]) or self.in_stop_gap(date, s) for s in rows) for rows in ends):
            date = None
        import datetime
        def last_day(end):
            return (datetime.date.fromisoformat(end) - datetime.timedelta(days=1)).isoformat()
        def bound(date):
            hi = edtf_range(date)[1] if date else ride.get("created", self.today)
            for line, e in ride["edges"]:
                rows = self.attrs_of(e, line)
                if rows:
                    h = max(r["valid_to_hi"] or MAXD for r in rows)
                    if h < MAXD:
                        hi = min(hi, last_day(h))
            for rows in ends:
                h = max(s["valid_to_hi"] or MAXD for s in rows)
                if h < MAXD:
                    hi = min(hi, last_day(h))
            return hi
        hi = bound(date)
        if date and hi < edtf_range(date)[0]:
            hi = bound(None)
        return hi

    def in_stop_gap(self, date, s):
        """정차 기간 사이라 그날 서지 않았는가 (앱 inStopGap)."""
        lo, hi = edtf_range(date)
        return any(lo >= (f or "9999-12-31") and hi < (t or "0000-01-01") for f, t in self._stop_gaps[(s["route_id"], s["seq"])])

    def _end_stops(self, ride):
        """승하차한 끝의 정차 행. 잘린 끝은 통과라 안 본다. 그날 맡은 노선의 계통에서 찾는다."""
        if not ride.get("ends") or ride["ends"][0] not in self._stops:
            return []
        rid, a, b = ride["ends"]
        out = []
        for at, node, on in ((0, a, ride.get("alighted", (True, True))[0]), (-1, b, ride.get("alighted", (True, True))[1])):
            if not on:
                continue
            rows = []
            if ride["edges"]:
                for route in self.line_routes[ride["edges"][at][0]]:
                    rows += [s for s in self._stops[route] if s["node_id"] == node and s["is_stop"]]
            rows = rows or [s for s in self._stops[rid] if s["node_id"] == node and s["is_stop"]]
            if rows:
                out.append(rows)
        return out

    def denom_units(self, basis, carryover, cls="normal"):
        """denominator_unit에서 기준별 단위 집합."""
        out = {}
        for (k, c), u in self.units.items():
            if c != carryover or u["class"] != cls:
                continue
            f_lo = edtf_range(u["valid_from"])[0]
            t_lo, t_hi = edtf_range(u["valid_to"])
            if basis == "alltime":
                out[k] = u
            elif basis == "current":
                if (f_lo is None or f_lo <= self.today) and self.today < (t_hi or MAXD):
                    out[k] = u
            else:
                if year_certain(int(basis), u["valid_from"], u["valid_to"]):
                    out[k] = u
        return out

    def undecided_units(self, year, carryover, cls="normal"):
        """Y년 판정 불가 단위: 그해와 겹칠 수 있지만 확실하지 않음 (§5.4)."""
        out = {}
        for (k, c), u in self.units.items():
            if c != carryover or u["class"] != cls:
                continue
            f_lo = edtf_range(u["valid_from"])[0]
            t_hi = edtf_range(u["valid_to"])[1]
            if overlaps_year(year, f_lo, t_hi) and not year_certain(year, u["valid_from"], u["valid_to"]):
                out[k] = u
        return out

    def completion(self, rides, basis, carryover, scope_edges=None):
        """rides: [{date, edges:[(line,edge)], created?}] 저장 때 맞춘 노선 기준."""
        den = self.denom_units(basis, carryover)
        if scope_edges is not None:
            den = {k: v for k, v in den.items() if v["edge_id"] in scope_edges}
        hit = set()
        for r in rides:
            if basis not in ("alltime", "current"):
                if self.effective_hi(r) > f"{basis}-12-31":
                    continue
            for line, e in r["edges"]:
                k = self.unit_of(line, e, carryover)
                if k in den:
                    hit.add(k)
        return dict(num_km=round(sum(den[k]["km"] for k in hit), 1), den_km=round(sum(v["km"] for v in den.values()), 1),
                    num_units=len(hit), den_units=len(den), keys=sorted(hit))

    def ride_of(self, res, date=None, alighted=(True, True)):
        """expand 결과 → 저장되는 (노선, edge)."""
        out = []
        for ln, es in res.get("legs", {}).items():
            if ln in self.routes:      # service/cross는 route 키
                ln2 = self.routes[ln]["line_id"]
            else:
                ln2 = ln
            out += [(ln2, e) for e in es]
        ends = (res.get("route"), res["nodes"][0], res["nodes"][-1]) if res.get("nodes") else None
        return dict(date=date, edges=out, ends=ends, alighted=alighted)


    # ------------ 역 선택기 보조 -------------
    def picker_lineage(self, route_id, date):
        """§8 탑승일 상태표: 그날 상태를 같은 lineage의 멤버십으로 판정.
        route_stop 기간은 그 계통의 기간뿐이라, 앞뒤 노선의 계통에서 같은 노드의 정차 행을 찾아 다시 판정한다."""
        d = normalize_date(date)
        line = self.routes[route_id]["line_id"]
        rows = self.picker(route_id, d)
        if d is None:
            return rows
        adj = collections.defaultdict(list)
        for _, e, a, b in self.route_edges(route_id):
            adj[a].append(e)
            adj[b].append(e)
        for row in rows:
            if row["state"] not in ("before_open", "closed"):
                continue
            for e in adj[row["node"]]:
                attr, st = self.attr_on(e, line, d)
                if attr is None or attr["line_id"] == line:
                    continue
                for rid in self.line_routes[attr["line_id"]]:
                    for s in self._stops[rid]:
                        if s["node_id"] != row["node"] or not s["is_stop"]:
                            continue
                        if state_on(d, s["valid_from_lo"], s["valid_from_hi"], s["valid_to_lo"], s["valid_to_hi"]) in ("yes", "maybe"):
                            # 저장될 노선에서 그날 탈 수 있어야 고른다. 운휴면 운휴 (Dart selector _savedState와 같음)
                            uses = [self.edge_usable(r2, e2, d)[0] for r2 in self.line_routes[attr["line_id"]] for e2 in adj[row["node"]]]
                            if any(u in ("ok", "maybe") for u in uses):
                                row["state"], row["selectable"] = "open", True
                            elif "suspended" in uses:
                                row["state"], row["selectable"] = "suspended", False
                            else:
                                row["state"], row["selectable"] = "line_closed", False
                            row["saved_as"] = attr["line_id"]
                            row["km_on_date"] = row["km_on_date"]
        return rows

    def archive_rows(self, route_id):
        """열람 전용 역: 항상 선택 불가."""
        return [dict(r) for r in self.db.execute("SELECT * FROM archive_stop WHERE route_id=?", (route_id,))]


# ============================================================ 시나리오 ====
class Report:
    def __init__(self, only=None):
        self.rows = []
        self.only = only

    def add(self, sid, title, expected, actual, ok, note=""):
        verdict = "NOTE" if ok is None else ("PASS" if ok else "FAIL")
        self.rows.append(dict(id=sid, title=title, expected=str(expected), actual=str(actual), verdict=verdict, note=note))
        print(f"[{verdict}] {sid} {title}\n    기대: {expected}\n    결과: {actual}" + (f"\n    비고: {note}" if note else ""))


def approx(a, b, tol=0.05):
    return a is not None and abs(a - b) <= tol


def pick_names(rows, only_sel=True):
    return [r["name"] for r in rows if r["selectable"] or not only_sel]


def scenarios(A, R):
    N = lambda r, t: A.find_node(r, t)[0]
    T = A.today

    # ---- A. 기본 펼치기 --------------------------------------------------
    r = "r_tokaido_shinkansen"
    x = A.expand(r, N(r, "東京"), N(r, "新大阪"), T)
    R.add("A1", "東海道新幹線 東京→新大阪 오늘", "552.6km (공식 営業キロ), 16구간", f"{x['status']} {x['km']}km {len(x['edges'])}구간",
          x["status"] == "ok" and approx(x["km"], 552.6) and len(x["edges"]) == 16)
    p = A.picker(r, T)
    R.add("A1b", "東海道新幹線 역 선택기", "17역 전부 선택 가능(品川·新横浜 포함)", f"{sum(q['selectable'] for q in p)}역, 2번째={p[1]['name']}",
          sum(q["selectable"] for q in p) == 17)

    r = "r_tokaido_main_line"
    x = A.expand(r, N(r, "東京"), N(r, "神戸"), T)
    R.add("A2", "東海道本線 東京→神戸 오늘", "589.5km (공식)", f"{x['status']} {x['km']}km {len(x['edges'])}구간",
          x["status"] == "ok" and approx(x["km"], 589.5))

    x = A.expand_service("s_yamanote_loop", "n_shinagawa", None, T, full_lap=True)
    y = A.expand_service("s_yamanote_loop", "n_tokyo", None, T, direction="seq_down", full_lap=True)
    R.add("A3", "山手線 한 바퀴 (s_yamanote_loop)", "34.5km = 山手線 20.6 + 東北本線 7.1 + 東海道本線 6.8, 30구간, 양방향 동일",
          f"up {x['km']} {dict(x['line_km'])} {len(x['edges'])}구간 / down {y['km']}",
          approx(x["km"], 34.5) and approx(y["km"], 34.5) and len(x["edges"]) == 30
          and x["line_km"]["l_yamanote_line"] == 20.6)
    x = A.expand_service("s_yamanote_loop", "n_shinjuku", "n_ueno", T, direction="seq_up")
    y = A.expand_service("s_yamanote_loop", "n_shinjuku", "n_ueno", T, direction="seq_down")
    R.add("A3b", "山手線 일부 양방향 (新宿→上野)", "池袋経由 13.5 (新宿→田端 10.0 + 田端→上野 3.5) / 東京経由 21.0, 합 34.5", f"{x['km']} / {y['km']}",
          approx(x["km"], 13.5) and approx(y["km"], 21.0))

    r = "r_osaka_loop_line"
    x = A.expand_service("s_osaka_loop", "n_osaka", "n_kyobashi", T, direction="seq_down")
    y = A.expand_service("s_osaka_loop", "n_osaka", "n_kyobashi", T, direction="seq_up")
    z = A.expand_service("s_osaka_loop", "n_tennoji", None, T, full_lap=True)
    R.add("A4", "大阪環状線 大阪→京橋 양방향 (s_osaka_loop)", "桜ノ宮経由 4.2km / 西九条経由 17.5km (関西本線 1.0 포함), 합 21.7",
          f"{x['km']} {dict(x['line_km'])} / {y['km']} {dict(y['line_km'])} / 일주 {z['km']}",
          approx(x["km"], 4.2) and approx(y["km"], 17.5) and approx(z["km"], 21.7))
    rr = A.routes[r]
    R.add("A4b", "大阪環状線 계통의 closed (§2.7 설계: closed: true)", "route.closed=1 또는 service로 대체", f"route.closed={rr['closed']}, {rr['from_node']}→{rr['to_node']} (열린 계통), service.closed=1",
          None, "공식 계통이 天王寺→新今宮으로 열려 있어 계통 화면은 한쪽 방향만. 순환 입력은 service로 가능")

    r = "r_oedo_line"
    x = A.expand(r, "n_tochomae", "n_hikarigaoka", T)
    R.add("A5", "大江戸線 都庁前→光が丘", "12.1km (전 구간 40.7 − 환상부 28.6), 10구간, 고리를 돌지 않음", f"{x['status']} {x['km']}km {len(x['edges'])}구간",
          x["status"] == "ok" and approx(x["km"], 12.1) and len(x["edges"]) == 10)
    a, b = "n_shinjuku_toei", "n_iidabashi_toei"
    x0 = A.expand(r, a, b, T)
    x = A.expand(r, a, b, T, direction="seq_up")
    y = A.expand(r, a, b, T, direction="seq_down")
    R.add("A6", "大江戸線 新宿→飯田橋 올가미", "都庁前経由 6.6km(기본·짧은 쪽) / 代々木経由 22.0km, 합 28.6", f"기본 {x0['km']} / up {x['km']} / down {y['km']}",
          approx(x0["km"], 6.6) and approx(x["km"], 6.6) and approx(y["km"], 22.0))
    x = A.expand(r, "n_hikarigaoka", "n_iidabashi_toei", T, direction="seq_up")
    y = A.expand(r, "n_hikarigaoka", "n_iidabashi_toei", T, direction="seq_down")
    R.add("A6b", "大江戸線 光が丘→飯田橋 (꼬리→고리) 두 방향", "17.9km / 34.9km", f"up {x['km']} / down {y['km']}",
          approx(x["km"], 17.9) and approx(y["km"], 34.9))
    seqs = A.seq_of(r, "n_tochomae")
    R.add("A6c", "大江戸線 같은 역 두 행 (route_stop)", "都庁前 seq 2개 (0, 28)", f"{seqs}", seqs == [0, 28])

    x = A.expand_service("s_chuo_rapid", "n_tokyo", "n_takao", T)
    R.add("A7", "運転系統 中央快速線 東京→高尾 (§2.7 크레딧 예시)", "53.1km = 東北 1.3 + 中央 8.3 + 山手 0.7 + 中央 42.8", f"{x.get('km')} {dict(x.get('line_km', {}))} legs={[k for k in x.get('legs', {})]}",
          approx(x.get("km"), 53.1))

    x = A.expand("r_hakodate_main_line", "n_onuma", "n_mori", T)
    y = A.expand("r_hakodate_main_line_onuma_mori", "n_onuma", "n_mori", T)
    R.add("A8", "같은 양 끝의 병행 계통 函館本線 大沼→森 (§2.7)", "본선 22.5km / 砂原支線 35.3km, route_id로 구분", f"{x['km']} / {y['km']}", approx(x["km"], 22.5) and approx(y["km"], 35.3))
    ls = A.line_routes["l_chitose_line"]
    x = A.expand_cross("n_new_chitose_airport", "n_numanohata", T, ls)
    R.add("A9", "같은 노선 계통 넘기 千歳線 新千歳空港→沼ノ端 (§2.8 F)", "21.0km = 공항지선 2.6 + 본선 18.4, 南千歳에서 2 leg", f"{x['km']} {[(k, round(sum(A.km[e] for e in v), 1)) for k, v in x['legs'].items()]}",
          approx(x["km"], 21.0) and len(x["legs"]) == 2)
    # ディズニーリゾートライン은 반시계 한 방향이라 계통 순서의 반대(seq_down)로만 돈다 (DESIGN §8 한 방향 운행)
    x = A.lap("r_disney_resort_line", "n_resort_gateway", T, direction="seq_down")
    # 札幌市電은 법적 4노선(一条線·山鼻西線·山鼻線·都心線)으로 나눴으므로(공식 노선 구성 2026-11-09) 한 노선 고리는 ユーカリが丘線으로 본다
    y = A.lap("r_yukarigaoka_line", "n_koen", T)
    z = A.lap("r_yukarigaoka_line", "n_koen", "1983-01-01")
    w = A.record("r_disney_resort_line", "n_resort_gateway", "n_resort_gateway", T, direction="seq_down")
    R.add("A11b", "저장·재해석에서 from==to + 방향은 한 바퀴", "ディズニーリゾートライン 5.0km", f"{w['status']} {w['km']}", w["status"] == "ok" and approx(w["km"], 5.0))
    w = A.record("r_disney_resort_line", "n_resort_gateway", "n_resort_gateway", T, direction="seq_up")
    v = A.record("r_yukarigaoka_line", "n_chugakko", "n_joshidai", T)
    u = A.record("r_fujishiro_line", "n_onuma", "n_nanae", T)
    q = A.record("r_joban_line", "n_mito", "n_kairakuen", "2026-02-20")
    R.add("A11d", "한 방향 운행·정차 (DESIGN §8)", "디즈니 반대 한 바퀴 one-way, ユーカリが丘 中学校→女子大 돌아 2.3km, 藤城線 大沼→七飯 one-way, 水戸→偕楽園 stop-direction",
          f"{w.get('reason')} / {v['km']} {v.get('around')} / {u.get('reason')} / {q.get('reason')}",
          w.get("reason") == "one-way" and approx(v["km"] or 0, 2.3) and v.get("around") and u.get("reason") == "one-way" and q.get("reason") == "stop-direction")
    w = A.record("r_yukarigaoka_line", "n_koen", "n_koen", "1983-01-01", direction="seq_up")
    R.add("A11c", "고리가 없던 날의 한 바퀴는 날짜 모름으로 저장", "ok, 날짜 없음", f"{w['status']} {w['saved_date']}", w["status"] == "ok" and w["saved_date"] is None)
    R.add("A11", "닫힌 계통 한 바퀴 (route.closed=1)", "ディズニーリゾートライン 5.0km, ユーカリが丘線 고리, 1983-01-01은 아직 안 닫힘(1983-09-22 井野)", f"{x['km']} / {y['km']} / 1983 {z['status']} {z.get('reason')}",
          approx(x["km"], 5.0) and y["status"] != "invalid" and z["status"] == "invalid")
    m = A.db.execute("SELECT count(*) FROM route WHERE closed=1 AND line_id LIKE '%meijou%'").fetchone()[0]
    x = A.expand_cross("n_kanayama_nagoya_city", "n_aratama_bashi", T, ["r_meijo_line", "r_meijo_meiko_line"])
    R.add("A10", "名城線 순환 (§2.7 설계: closed: true)", "closed=1 계통 또는 closed service, 일주 26.4km", f"closed 계통 {m}개, 노선 2개로 나뉨(名城線 17.5 / 名城線・名港線 8.9+6.0), 名城線 service 없음", None,
          "大曽根 넘어가는 탑승은 2 leg로 입력하면 되고 km는 맞음. 순환 토글은 없음")

    # ---- B. 숨은 노드·직통 -----------------------------------------------
    r1, r2 = "r_nagoya_main_line", "r_inuyama_line"
    svc = A.db.execute("SELECT count(*) FROM service_part WHERE route_id IN (?,?)", (r1, r2)).fetchone()[0]
    R.add("B1", "名鉄名古屋→犬山 입력 경로 (extend_to 또는 service, §2.8 F)", "犬山線 화면에서 東枇杷島까지 extend_to, 또는 service 존재",
          f"犬山線 extend_to={A.routes[r2]['extend_to']}, is_extension 행 {sum(q['is_extension'] for q in A.picker(r2, T))}, 名鉄 service 부품 {svc}개, 犬山線 첫 선택 역={A.picker(r2, T)[0]['name']}",
          bool(A.routes[r2]["extend_to"]) or svc > 0, "extend_to가 있어도 東枇杷島는 끝 역이라 그 뒤 역은 名古屋本線 화면에서 잇거나 B1b 우회가 필요")
    x = A.expand_cross("n_meitetsu_nagoya", "n_inuyama", T, [r1, r2])
    R.add("B1b", "名鉄名古屋→犬山 숨은 노드 자동 분할 (우회)", "28.2km = 名古屋本線 3.3 + 犬山線 24.9, 숨은 노드 1개, 분기점 이름 비공개",
          f"{x['km']} {x['line_km']} hidden={x['hidden']} public에 없음={[h not in A.public for h in x['hidden']]}",
          approx(x["km"], 28.2) and len(x["hidden"]) == 1)
    n = A.db.execute("SELECT count(*) FROM route_link WHERE route_id=? AND other_line_id='l_inuyama_line'", (r1,)).fetchone()[0]
    atedge = A.db.execute("SELECT count(*) FROM route_link WHERE at_edge=1").fetchone()[0]
    R.add("B1c", "名古屋本線 화면의 犬山線 분기 줄 (§8.1 at_edge)", "route_link 1행 이상(at_edge=1)", f"犬山線 행 {n}개, 전체 at_edge=1 행 {atedge}개", n > 0,
          "枇杷島分岐点 분기가 화면에 나오지 않음")

    r1, r2 = "r_toyoko_line", "r_minatomirai_line"
    x = A.expand(r1, N(r1, "渋谷"), "n_yokohama_tokyu_railways", T)
    y = A.expand(r2, "n_yokohama_yokohama_minatomirai", N(r2, "元町・中華街"), T)
    hub = A.db.execute("SELECT count(*) FROM hub_member a JOIN hub_member b ON a.hub_id=b.hub_id WHERE a.node_id='n_yokohama_tokyu_railways' AND b.node_id='n_yokohama_yokohama_minatomirai'").fetchone()[0]
    link = [l for row in A.picker(r1, T) if row["node"] == "n_yokohama_tokyu_railways" for l in row["links"] if l["other_line_id"] == "l_minatomirai_line"]
    R.add("B2", "東横線→みなとみらい線 직통 (2 leg)", "渋谷→横浜 24.2 + 横浜→元町・中華街 4.1 = 28.3, 横浜 hub로 이어짐", f"{x['km']}+{y['km']}={round(x['km'] + y['km'], 1)}, hub {hub}, 東横線 화면 links={[l['kind'] for l in link]}",
          approx(x["km"], 24.2) and approx(y["km"], 4.1) and hub == 1 and link)
    cont = [l for l in link if l["kind"] == "continue"]
    R.add("B2b", "東横線 끝 역 '끝에서 이어짐' (§8.1, §2.9 예시)", "continue 행 (みなとみらい線 또는 副都心線)", f"continue {len(cont)}행 (transfer로만 표시)", None,
          "기록은 가능. 표시만 환승 캡슐로 나옴. 아래 전수 점검 참고")
    x = A.expand(r1, "n_yokohama_tokyu_railways", N(r1, "桜木町"), "2003-06-01")
    y = A.record(r1, "n_yokohama_tokyu_railways", N(r1, "桜木町"), "2010-06-01")
    z = [q for q in A.picker(r2, "2003-06-01") if q["selectable"]]
    R.add("B2c", "東横線 横浜→桜木町 2003 / 2010, みなとみらい線 2003", "2003 2.1km, 2010 날짜 모름, みなとみらい 2003 선택 0역", f"{x['km']} / demoted={y['demoted']} / {len(z)}역",
          approx(x["km"], 2.1) and y["demoted"] and len(z) == 0)

    l03 = [l for row in A.picker(r1, "2003-06-01") if row["node"] == "n_yokohama_tokyu_railways" for l in row["links"] if l["other_line_id"] == "l_minatomirai_line"]
    R.add("B2d", "환승 표시도 날짜를 따름 (2003 東横線 横浜)", "みなとみらい線 행 없음", f"{len(l03)}행", len(l03) == 0)

    # ---- C. 이관 --------------------------------------------------------
    r = "r_shinetsu_main_line"
    a, b, c = "n_karuizawa", "n_nagano", "n_shinonoi"
    x = A.expand(r, a, b, "2000-06-01")
    R.add("C1", "信越本線 軽井沢→長野 2000 (시나리오 그대로)", "1997-10-01 이관 뒤라 しなの鉄道 65.1 + 信越本線 9.3 = 74.4 로 맞춰 저장", f"{x['km']} {x['line_km']}",
          approx(x["km"], 74.4) and x["line_km"].get("l_shinano_railway_line") == 65.1, "2000년 신에츠는 이미 이관 뒤. 두 단위 시험은 1996년으로 함(C2)")
    old = A.expand(r, a, c, "1996-06-01")
    new = A.expand("r_shinano_railway_line", a, c, "2020-06-01")
    ro, rn = A.ride_of(old, "1996-06-01"), A.ride_of(new, "2020-06-01")
    es = set(old["edges"])
    res = {}
    for carry in ("on", "off"):
        for basis in ("alltime", "current"):
            res[(carry, basis, "1996만")] = A.completion([ro], basis, carry, es)
            res[(carry, basis, "둘 다")] = A.completion([ro, rn], basis, carry, es)
    s = {f"{k[0]}/{k[1]}/{k[2]}": f"{v['num_km']}/{v['den_km']} ({v['num_units']}/{v['den_units']})" for k, v in res.items()}
    ok = (res[("on", "alltime", "둘 다")]["den_units"] == 18 and res[("on", "alltime", "1996만")]["num_units"] == 18
          and res[("off", "alltime", "둘 다")]["den_units"] == 36 and res[("off", "alltime", "1996만")]["num_units"] == 18
          and res[("off", "alltime", "둘 다")]["num_units"] == 36
          and res[("off", "current", "1996만")]["num_units"] == 0 and res[("on", "current", "1996만")]["num_units"] == 18)
    R.add("C2", "信越本線 1996 + しなの鉄道 2020, 軽井沢→篠ノ井 18구간", "켬: 18단위(65.1), 1996만 타도 18/18. 끔: 역대 36단위(130.2), 현행은 1996 탑승이 0", s, ok)
    u = A.expand(r, a, c, "2000-06-01")
    ru = A.ride_of(u, "2000-06-01")
    v = A.completion([ru, rn], "alltime", "off", es)
    R.add("C2b", "시나리오 그대로 2000 + 2020 승계 끔", "두 기록 모두 しなの鉄道 단위이므로 18단위만 참 (요청의 '두 단위'는 1996년 탑승이어야 성립)", f"{v['num_units']}단위 {v['num_km']}km 채움 / 분모 {v['den_units']}", v["num_units"] == 18)

    p = A.picker("r_shinano_railway_line", "1990-06-01")
    q = A.picker_lineage("r_shinano_railway_line", "1990-06-01")
    R.add("C3", "しなの鉄道線 화면 1990 (§8 예시: 영업 중, 저장은 信越本線)", "역 선택 가능, 저장 노선 信越本線",
          f"route_stop 기간만: 선택 {sum(z['selectable'] for z in p)}역 / lineage 보정: 선택 {sum(z['selectable'] for z in q)}역, 저장 {sorted({z.get('saved_as') for z in q if z.get('saved_as')})}",
          sum(z["selectable"] for z in q) > 0, "route_stop이 계통 기간으로 잘려 있어 그대로는 0역. 앱은 picker_lineage로 앞 노선 계통을 고른다")

    r = "r_hokuriku_main_line"
    a, b = "n_kanazawa", "n_toyama"
    x = A.expand(r, a, b, "2010-06-01")
    y20 = A.expand(r, a, b, "2020-06-01")
    z = A.expand("r_ainokaze_toyama_railway_line", "n_kurikara", "n_toyama", "2020-06-01")
    es = set(x["edges"])
    ro, rn = A.ride_of(x, "2010-06-01"), A.ride_of(y20, "2020-06-01")
    on = A.completion([ro, rn], "alltime", "on", es)
    off = A.completion([ro, rn], "alltime", "off", es)
    off1 = A.completion([ro], "current", "off", es)
    on1 = A.completion([ro], "current", "on", es)
    R.add("C4", "北陸本線 金沢→富山 2010 / あいの風とやま 2020", "59.4km, 2020은 IRいしかわ 17.8 + あいの風 41.6, 켬 13단위, 끔 26단위, 끔 현행은 2010 탑승 0",
          f"2010 {x['line_km']} / 2020 {y20['line_km']} / あいの風 단독 {z['km']} / 켬 {on['num_units']}/{on['den_units']} / 끔 {off['num_units']}/{off['den_units']} / 현행 2010만 켬 {on1['num_units']} 끔 {off1['num_units']}",
          approx(x["km"], 59.4) and y20["line_km"].get("l_ainokaze_toyama_railway_line") == 41.6 and on["den_units"] == 13 and off["den_units"] == 26 and off1["num_units"] == 0 and on1["num_units"] == 13)

    r = "r_aoimori_railway_line"
    a, b = "n_metoki", "n_aomori"
    o = {d: A.expand(r, a, b, d) for d in ("2000-01-01", "2005-01-01", "2015-01-01")}
    ro = A.ride_of(o["2000-01-01"], "2000-01-01")
    rn = A.ride_of(o["2015-01-01"], "2015-01-01")
    es = set(o["2000-01-01"]["edges"])
    on = A.completion([ro, rn], "alltime", "on", es)
    off = A.completion([ro, rn], "alltime", "off", es)
    R.add("C5", "青い森鉄道 目時→青森", "121.9km. 2005=青い森 25.9+東北 96.0 (2002 目時~八戸 이관), 2015=전부 青い森, 켬 27단위, 끔 54단위",
          f"{ {d: v['line_km'] for d, v in o.items()} } 켬 {on['num_units']}/{on['den_units']} 끔 {off['num_units']}/{off['den_units']}",
          approx(o["2015-01-01"]["km"], 121.9) and o["2005-01-01"]["line_km"].get("l_aoimori_railway_line") == 25.9 and on["den_units"] == 27 and off["den_units"] == 54)

    r = "r_rias_line"
    a, b = "n_miyako", "n_kamaishi"
    o = A.expand(r, a, b, "2010-06-01")
    n = A.expand(r, a, b, "2020-06-01")
    ro, rn = A.ride_of(o, "2010-06-01"), A.ride_of(n, "2020-06-01")
    es = set(o["edges"])
    on = A.completion([ro, rn], "alltime", "on", es)
    off = A.completion([ro, rn], "alltime", "off", es)
    R.add("C6", "リアス線 宮古→釜石 2019 이관", "55.4km, 2010=山田線, 2020=リアス線, 켬 15단위, 끔 30단위", f"{o['line_km']} / {n['line_km']} / 켬 {on['num_units']}/{on['den_units']} / 끔 {off['num_units']}/{off['den_units']}",
          approx(n["km"], 55.4) and "l_yamada_line" in o["line_km"] and on["den_units"] == 15 and off["den_units"] == 30)
    st = A.record("r_yamada_line", "n_miyako", "n_kamaishi", "2018-01-01")
    R.add("C6b", "山田線 宮古→釜石 2018 (2011~2019 불통)", "그날 운휴 → 날짜 모름으로 저장", f"status={st['status']} saved_date={st['saved_date']} demoted={st['demoted']}",
          st["demoted"], "edge_life에 2011-03-12~2019-03-23 suspended 행이 없음. 아래 재해 불통 표 참고")
    p18 = {q["node"]: q for q in A.picker("r_yamada_line", "2018-01-01")}
    p20 = {q["node"]: q for q in A.picker(r, "2020-06-01")}
    R.add("C7", "織笠 이전: 山田線 시절 역과 リアス線 역이 다른 노드", "山田線=n_orikasa(宮古 기점 28.7km), リアス=n_orikasa_sanriku, 전체 km 불변 55.4",
          f"山田線 {p18.get('n_orikasa', {}).get('km_cum')}, リアス {p20.get('n_orikasa_sanriku', {}).get('km_cum')}, リアス 쪽 n_orikasa 표시={'n_orikasa' in p20}, 山田線 쪽 n_orikasa_sanriku 표시={'n_orikasa_sanriku' in p18}",
          "n_orikasa" in p18 and "n_orikasa_sanriku" in p20 and "n_orikasa" not in p20 and "n_orikasa_sanriku" not in p18)
    names18 = [q["name"] for q in A.picker("r_yamada_line", "2005-01-01")][17:]
    R.add("C7b", "山田線 2005년 宮古~釜石 역 목록", "磯鶏·津軽石·豊間根·陸中山田… 払川·八木沢・宮古短大는 2019-03-23 三鉄 개업이라 없음 (ja.wikipedia 각 역 문서)", f"{names18}",
          "払川" not in names18 and "八木沢・宮古短大" not in names18 and "津軽石" in names18)

    # ---- D. 이설 --------------------------------------------------------
    r = "r_agatsuma_line"
    a, b = "n_iwashima", "n_naganohara_kusatsuguchi"
    x, y, u = A.expand(r, a, b, "2010-06-01"), A.expand(r, a, b, "2020-06-01"), A.expand(r, a, b, None)
    bd1, bd2 = A.expand(r, a, b, "2014-09-30"), A.expand(r, a, b, "2014-10-01")
    R.add("D1", "吾妻線 岩島→長野原草津口", "2010 11.8km(옛), 2020 11.5km(새), 경계 2014-09-30 옛/10-01 새, 날짜 모름은 needs_input 2안",
          f"{x['km']} / {y['km']} / {bd1['km']},{bd2['km']} / {u['status']} {u.get('options')}",
          approx(x["km"], 11.8) and approx(y["km"], 11.5) and u["status"] == "needs_input" and len(u["options"]) == 2)
    v = A.expand(r, "n_shibukawa", "n_omae", None, resolve_unknown=True)
    w = A.expand(r, "n_shibukawa", "n_omae", None, as_of="2010-01-01")
    R.add("D1b", "吾妻線 渋川→大前 날짜 모름: 모름(partial) / 옛 선로(as_of)", "partial=공통 구간 43.8km, as_of 2010=55.6km", f"{v['status']} {v['km']} / {w['status']} {w['km']}", v["status"] == "partial" and approx(v["km"], 43.8) and approx(w["km"], 55.6))
    p = {q["node"]: q for q in A.picker(r, "2010-06-01")}
    R.add("D1c", "吾妻線 2010 역 선택기 표시 km (§8 고른 날짜)", "長野原草津口 42.3 (route_stop km_cum 42.0은 현행값)", f"km_cum {p['n_naganohara_kusatsuguchi']['km_cum']} / 날짜 계산 {p['n_naganohara_kusatsuguchi']['km_on_date']}",
          approx(p["n_naganohara_kusatsuguchi"]["km_on_date"], 42.3), "km_cum은 한 값이라 앱이 edge로 다시 더해야 함")
    ride10, ride20 = A.ride_of(x, "2010-06-01"), A.ride_of(y, "2020-06-01")
    es = set(x["edges"]) | set(y["edges"])
    c1 = A.completion([ride10], "current", "on", es)
    c2 = A.completion([ride20], "current", "on", es)
    c3 = A.completion([ride10, ride20], "alltime", "on", es)
    c4 = A.completion([ride10], "alltime", "off", es)
    R.add("D1d", "吾妻線 이설 완주", "옛 탑승은 현행 0, 새 탑승은 현행 11.5/11.5, 역대 분모 23.3(옛+새)", f"현행 옛만 {c1['num_km']}/{c1['den_km']}, 새만 {c2['num_km']}/{c2['den_km']}, 역대 {c3['num_km']}/{c3['den_km']}, 끔 역대 옛만 {c4['num_km']}/{c4['den_km']}",
          c1["num_km"] == 0 and c2["num_km"] == 11.5 and c3["den_km"] == 23.3)
    y14 = A.completion([], "2014", "on", es)
    R.add("D1e", "吾妻선 2014 연도 분모 (이설한 해)", "옛+새 함께 23.3km", f"{y14['den_km']} ({y14['den_units']}단위)", y14["den_km"] == 23.3)

    r = "r_joban_line"
    a, b = A.find_node(r, "駒ヶ嶺")[0], "n_hamayoshida"
    x, y, u = A.expand(r, a, b, "2010-06-01"), A.expand(r, a, b, "2020-06-01"), A.expand(r, a, b, None)
    R.add("D2", "常磐線 駒ケ嶺→浜吉田", "2010 18.2km(옛), 2020 18.8km(새, 2016-12-10), 날짜 모름 2안", f"{x['km']} / {y['km']} / {u['status']} {u.get('options')}",
          approx(x["km"], 18.2) and approx(y["km"], 18.8) and u["status"] == "needs_input" and len(u["options"]) == 2)
    st = A.record(r, a, b, "2013-06-01")
    R.add("D2b", "常磐線 駒ケ嶺→浜吉田 2013 (2011~2016 불통)", "운휴 → 날짜 모름", f"saved_date={st['saved_date']} demoted={st['demoted']} km={st['km']}", st["demoted"], "옛 edge가 2016-12-10까지 open")

    # 女川는 역 이전 옛 자리 노드(n_onagawa_old, 2015-03-21 전)와 새 자리 노드가 따로다 (wiki_insert_moves relabel, 재설계 결정 7).
    # 2010은 옛 자리까지 2.5km, 2020은 새 자리까지 2.3km, 2010에 새 자리는 그날 경로가 없다
    r = "r_ishinomaki_line"
    a, b, b0 = "n_urashuku", "n_onagawa", "n_onagawa_old"
    x, y, u, v = A.expand(r, a, b0, "2010-06-01"), A.expand(r, a, b, "2020-06-01"), A.expand(r, a, b, None), A.expand(r, a, b, "2010-06-01")
    R.add("D3", "石巻線 浦宿→女川", "2010 女川(旧) 2.5km, 2020 女川 2.3km(2015-03-21), 2010 새 자리 그날 경로 없음, 날짜 모름 새 자리 2.3km", f"{x['km']} / {y['km']} / {v['status']} / {u['status']} {u['km']}",
          approx(x["km"], 2.5) and approx(y["km"], 2.3) and v["status"] == "invalid" and u["status"] == "ok" and approx(u["km"], 2.3))
    st = A.record(r, a, b0, "2013-06-01")
    R.add("D3b", "石巻線 浦宿→女川 2013 (2011~2015 불통)", "운휴 → 날짜 모름", f"saved_date={st['saved_date']} demoted={st['demoted']}", st["demoted"], "옛 edge가 2015-03-21까지 open")
    xx = A.db.execute("SELECT count(*), sum(successor_edge_id IS NULL) FROM edge_link").fetchone()
    R.add("D4", "edge_link (옛 선로 → 새 선로)", "successor_edge_id가 새 edge를 가리킴", f"{xx[0]}행 중 NULL {xx[1]}", xx[1] == 0, "우회: 같은 양 끝 + valid_to=valid_from")

    # ---- E. 폐선 --------------------------------------------------------
    r = "r_sanko_line"
    a, b = "n_gotsu", "n_miyoshi"
    x, y = A.record(r, a, b, "2017-06-01"), A.record(r, a, b, "2019-06-01")
    l1, l2 = A.record(r, a, b, "2018-03-31"), A.record(r, a, b, "2018-04-01")
    R.add("E1", "三江線 江津→三次", "2017 108.1km 날짜 유지, 2019 날짜 모름 저장, 2018-03-31 유지, 04-01 모름", f"{x['km']} {x['saved_date']} / {y['km']} {y['saved_date']} / {l1['saved_date']} / {l2['saved_date']}",
          approx(x["km"], 108.1) and x["saved_date"] and y["saved_date"] is None and y["status"] == "ok" and l1["saved_date"] and l2["saved_date"] is None)
    p = A.picker(r, "2019-06-01")
    # 野井仮乗降場(1972~1973 수해 때)까지 36역
    R.add("E1b", "三江線 2019 역 선택기", "37역 모두 회색(이미 폐지), 날짜 모름이면 37역 선택", f"선택 {sum(q['selectable'] for q in p)} 상태 {collections.Counter(q['state'] for q in p)} / 모름 {sum(q['selectable'] for q in A.picker(r, None))}",
          sum(q["selectable"] for q in p) == 0 and sum(q["selectable"] for q in A.picker(r, None)) == 37)
    ride = dict(date=None, edges=A.ride_of(y)["edges"], created=T)
    c17 = A.completion([ride], "2017", "on", set(y["edges"]))
    c18 = A.completion([ride], "2018", "on", set(y["edges"]))
    R.add("E1c", "三江線 날짜 모름 기록의 연도 집계 (§2.8 J)", "유효 끝 2018-03-31: 2017 0, 2018 전체 108.1", f"끝={A.effective_hi(ride)}, 2017 {c17['num_km']}/{c17['den_km']}, 2018 {c18['num_km']}/{c18['den_km']}",
          c17["num_km"] == 0 and c18["num_km"] == 108.1)

    r = "r_sassho_line"
    a, b = "n_hokkaido_iryodaigaku", "n_shin_totsukawa"
    o = {d: A.record(r, a, b, d) for d in ("2020-04-17", "2020-04-20", "2020-05-01")}
    R.add("E2", "札沼線 北海道医療大学→新十津川", "47.6km. 2020-04-17 유지, 04-20·05-01은 마지막 운행(04-17) 뒤 → 날짜 모름", {d: (v["km"], v["saved_date"]) for d, v in o.items()},
          approx(o["2020-04-17"]["km"], 47.6) and o["2020-04-17"]["saved_date"] and o["2020-04-20"]["saved_date"] is None and o["2020-05-01"]["saved_date"] is None)
    u = A.picker(r, "2020-04-20")
    R.add("E2b", "札沼線 2020-04-20 역 선택기", "桑園~北海道医療大学 13역 선택(ロイズタウン은 2022 개업이라 제외), 그 뒤 불가", f"선택 {sum(q['selectable'] for q in u)}역, 마지막 선택 {[q['name'] for q in u if q['selectable']][-1]}",
          sum(q["selectable"] for q in u) == 13)
    e0 = A.db.execute("SELECT legal_abolition, last_service FROM edge_life WHERE edge_id=? ORDER BY valid_from_lo DESC LIMIT 1", (A.edge_between("n_toyogaoka", "n_sappinai"),)).fetchone()   # 운휴로 행이 나뉘면 마지막 행(폐지)
    R.add("E2c", "札沼線 법적 폐지일·마지막 운행일 둘 다 저장", "last_service=2020-04-17, legal=2020-05-07", tuple(e0), tuple(e0) == ("2020-05-07", "2020-04-17"))

    r = "r_sekisho_line_shin_yubari_yubari"
    a, b = "n_shin_yubari", "n_yubari"
    x, y = A.record(r, a, b, "2019-03-31"), A.record(r, a, b, "2019-04-01")
    R.add("E3", "夕張支線 新夕張→夕張", "16.1km, 2019-03-31 유지, 04-01 날짜 모름", f"{x['km']} {x['saved_date']} / {y['saved_date']}", approx(x["km"], 16.1) and x["saved_date"] and y["saved_date"] is None)
    r = "r_shinmei_line"
    a, b = "n_fukagawa", "n_nayoro"
    x, y = A.record(r, a, b, "1995-09-03"), A.record(r, a, b, "1995-09-04")
    R.add("E4", "深名線 深川→名寄", "121.8km, 1995-09-03 유지, 09-04 날짜 모름", f"{x['km']} {x['saved_date']} / {y['saved_date']}", approx(x["km"], 121.8) and x["saved_date"] and y["saved_date"] is None)

    r = "r_nemuro_main_line"
    a, b = N(r, "東鹿越"), N(r, "新得")
    x = A.record(r, a, b, "2017-06-01")
    y = A.record(r, a, b, "2016-08-30")
    p = {q["name"]: q["state"] for q in A.picker(r, "2017-06-01")}
    den = A.completion([], "2017", "on", set(x["edges"]))
    denc = A.completion([], "current", "on", set(x["edges"]))
    # 재개 없이 2024-04-01 폐지로 끝난 불통이라 마지막 운행 다음 날(2016-08-31)로 소급해 닫힌다 (DESIGN §2.2 「운행을 다시 시작하지 않고 끝난 휴지」, 결정 122)
    R.add("E5", "根室本線 東鹿越→新得 2017 (2016-08-31 불통, 2024-04-01 폐지)", "41.5km, 2017 → 날짜 모름, 幾寅 폐역, 2017 분모 제외(2016-08-31 소급 폐지), 현행 분모 제외", f"{x['km']} saved={x['saved_date']} / 2016-08-30 saved={y['saved_date']} / 幾寅={p.get('幾寅')} / 2017분모 {den['den_km']} / 현행 {denc['den_km']}",
          approx(x["km"], 41.5) and x["saved_date"] is None and y["saved_date"] and p.get("幾寅") == "closed" and den["den_km"] == 0 and denc["den_km"] == 0)

    # ---- F. 기준일 ------------------------------------------------------
    r = "r_tokaido_main_line"
    a, b = N(r, "東京"), N(r, "品川")
    x, y = A.record(r, a, b, "1949-12-31"), A.record(r, a, b, "1950-01-01")
    R.add("F1", "기준일 경계 (東海道本線 東京→品川)", "1949-12-31 → 날짜 모름, 1950-01-01 → 날짜 유지", f"{x['saved_date']} / {y['saved_date']}", x["saved_date"] is None and y["saved_date"] == "1950-01-01")
    r = "r_temiya_line"
    a, b = "n_minami_otaru", "n_temiya"
    x, y = A.record(r, a, b, "1960-06-01"), A.record(r, a, b, "1980-06-01")
    e = A.route_edges(r)[0][1]
    # 1943~48 여객 휴지가 있어 마지막 기간 행을 본다
    lg = A.db.execute("SELECT legal_abolition,valid_to FROM edge_life WHERE edge_id=? ORDER BY valid_from DESC", (e,)).fetchone()
    al = A.completion([], "alltime", "on", {x[1] for x in A.route_edges(r)})
    R.add("F2", "手宮線 南小樽→手宮", "2.8km. 여객 1962 끝·법적 1985. 1960년 탑승은 날짜 유지, 여객 영업 뒤(1980)는 날짜 모름, 역대 분모 2.8", f"{x['km']} saved={x['saved_date']}, 1980 saved={y['saved_date']}, 법적={lg[0]} 영업끝={lg[1]}, 역대 분모 {al['den_km']}",
          approx(x["km"], 2.8) and x["saved_date"] == "1960-06-01" and y["saved_date"] is None and lg[0] == "1985-11-05" and al["den_km"] == 2.8)
    r = "r_kobukuro_line"
    a, b = "n_kotake", "n_futase"
    x, y = A.record(r, a, b, "1969-12-07"), A.record(r, a, b, "1969-12-08")
    es = set(x["edges"])
    al = A.completion([], "alltime", "on", es)
    R.add("F3", "幸袋線 小竹→二瀬 (1969-12-08 폐지)", "7.6km. 마지막 영업일 12-07은 날짜 유지, 폐지일 12-08은 날짜 모름, 역대 분모 7.6", f"{x['km']} saved={x['saved_date']} / {y['saved_date']}, 역대 {al['den_km']}",
          approx(x["km"], 7.6) and x["saved_date"] == "1969-12-07" and y["saved_date"] is None and al["den_km"] == 7.6)

    # ---- G. 재해 BRT ----------------------------------------------------
    r = "r_kesennuma_line"
    a, b = "n_yanaizu", "n_kesennuma"
    x, y, z = A.record(r, a, b, "2011-03-11"), A.record(r, a, b, "2011-06-01"), A.record(r, a, b, "2024-06-01")
    es = set(x["edges"])
    cur, al = A.completion([], "current", "on", es), A.completion([], "alltime", "on", es)
    R.add("G1", "気仙沼線 柳津→気仙沼 BRT", "55.3km, 2011-03-11 유지, 그 뒤는 날짜 모름, 현행 분모 0, 역대 55.3", f"{x['km']} {x['saved_date']} / {y['saved_date']} / {z['saved_date']} / 현행 {cur['den_km']} 역대 {al['den_km']}",
          approx(x["km"], 55.3) and x["saved_date"] and y["saved_date"] is None and z["saved_date"] is None and cur["den_km"] == 0 and al["den_km"] == 55.3)
    r = "r_hitahikosan_line"
    a, b = "n_soeda", "n_yoake"
    x, y, z = A.record(r, a, b, "2019-06-01"), A.record(r, a, b, "2024-06-01"), A.record(r, a, b, "2017-07-05")
    p19 = collections.Counter(q["state"] for q in A.picker(r, "2019-06-01"))
    p24 = collections.Counter(q["state"] for q in A.picker(r, "2024-06-01"))
    es = set(z["edges"])
    y19, y24 = A.completion([], "2019", "on", es), A.completion([], "2024", "on", es)
    # 2017-07-05 마지막 운행 뒤 재개 없이 BRT로 끝나 2017-07-06으로 소급해 닫힌다(사유 brt 그대로, 결정 122)
    R.add("G2", "日田彦山線 添田→夜明", "29.2km, 2017-07-05 유지, 2019·2024 날짜 모름, 역 상태 closed, 2019·2024 분모 제외", f"{x['saved_date']} / {y['saved_date']} / 2017-07-05 {z['saved_date']} / 2019 {dict(p19)} / 2024 {dict(p24)} / 분모 2019 {y19['den_km']} 2024 {y24['den_km']}",
          approx(z["km"], 29.2) and z["saved_date"] and x["saved_date"] is None and y["saved_date"] is None and p19["closed"] >= 9 and p24["closed"] >= 9 and y19["den_km"] == 0 and y24["den_km"] == 0)
    la = A.db.execute("SELECT DISTINCT legal_abolition FROM edge_life WHERE edge_id=?", (x["edges"][0],)).fetchall()
    R.add("G2b", "日田彦山線 legal_abolition 값", "2027-03-31 (폐지 예정일, ja.wikipedia 日田彦山線)", [tuple(q) for q in la if q[0]], any(q[0] == "2027-03-31" for q in la))

    r = "r_hidaka_main_line"
    a, b = N(r, "鵡川"), N(r, "静内")
    x = A.record(r, a, b, "2018-06-01")
    z = A.db.execute("""SELECT l.status, count(*), round(sum(k.km),1) FROM edge_life l JOIN edge_km k ON k.edge_id=l.edge_id
        WHERE l.edge_id IN (SELECT edge_id FROM route_edge WHERE route_id=?) AND l.valid_from_lo>='2015-01-08' GROUP BY 1""", (r,)).fetchall()
    R.add("G3", "日高本線 鵡川→静内 2018 (2015-01-08~2021 불통, 鵡川~様似 116.0km)", "운휴 → 날짜 모름. suspended 116.0km", f"saved={x['saved_date']}, suspended 행 {[tuple(q) for q in z]}", x["saved_date"] is None,
          "SVC 표에 시작 역이 鵜苫로 들어가 끝 2구간 5.4km만 suspended")

    # ---- H. 역 신설·폐지 ------------------------------------------------
    r = "r_tokaido_main_line"
    tk = "n_takanawa_gateway"
    st = {d: next(q for q in A.picker(r, d) if q["node"] == tk)["state"] if any(q["node"] == tk for q in A.picker(r, d)) else None for d in ("2010-06-01", "2020-03-13", "2020-03-14", T)}
    R.add("H1", "高輪ゲートウェイ", "2010·2020-03-13 없음(개업 전), 2020-03-14 이후 선택 가능, 공식 소속 東海道本線", st,
          st["2010-06-01"] == "before_open" and st["2020-03-14"] == "open")
    x = A.expand(r, "n_shinagawa", "n_tamachi", "2010-06-01")
    y = A.expand(r, "n_shinagawa", "n_tamachi", T)
    R.add("H1b", "신설 전 기록이 나뉜 edge를 모두 채움 (§3.2)", "2010 品川→田町 2구간 2.2km, 오늘과 같은 edge", f"2010 {x['edges']} {x['km']} / 오늘 {y['edges']} {y['km']}", x["edges"] == y["edges"])

    r = "r_umeda_freight_line"
    p05 = {q["node"]: q for q in A.picker(r, "2005-06-01")}
    p24 = {q["node"]: q for q in A.picker(r, "2024-06-01")}
    R.add("H2", "大阪 うめきた 승강장 2005", "2023-03-18 개업이라 2005 불가, 2024 가능", f"2005 {p05['n_osaka']['state']}({p05['n_osaka']['name']}) / 2024 {p24['n_osaka']['state']}",
          p05["n_osaka"]["state"] != "open", "route_stop.valid_from=1988-04-24 (노선 시작일로 들어감)")
    r = "r_osaka_higashi_line"
    c = {d: sum(q["selectable"] for q in A.picker(r, d)) for d in ("2005-06-01", "2010-06-01", "2018-06-01", "2019-03-15", "2020-06-01")}
    R.add("H3", "おおさか東線", "2005 0역, 2010 7역(放出~久宝寺, 衣摺加美北 전), 2018 8역, 2019-03-15 8역, 2020 14역", c, c == {"2005-06-01": 0, "2010-06-01": 7, "2018-06-01": 8, "2019-03-15": 8, "2020-06-01": 14})
    r = "r_sassho_line"
    a = {d: next(q["state"] for q in A.picker(r, d) if q["node"] == "n_nakatoppu") for d in ("2005-06-01", "2010-06-01")}
    x = A.expand(r, "n_shimotoppu", "n_shin_totsukawa", "2010-06-01")
    R.add("H4", "폐역 中徳富 (2006-03-18) 선로는 그대로", "2005 선택 가능, 2010 불가, 2010 下徳富→新十津川 통과 5.0km", f"{a} / {x['status']} {x['km']}", a["2005-06-01"] == "open" and a["2010-06-01"] == "closed" and approx(x["km"], 5.0))
    x = A.record("r_yahiko_line", "n_higashi_sanjo", "n_echigo_osaki", "1985-XX-XX")
    y = A.record("r_yahiko_line", "n_higashi_sanjo", "n_echigo_osaki", "194X-XX-XX")
    z = A.record("r_yahiko_line", "n_higashi_sanjo", "n_echigo_osaki", "1986-XX-XX")
    R.add("H4b", "범위 날짜는 겹치면 유지, 기준일에 걸치면 날짜 모름, 겹치지 않으면 날짜 모름", "1985 유지, 194X·1986 모름",
          f"{x['saved_date']}, {y['saved_date']}, {z['saved_date']}",
          x["saved_date"] == "1985-XX-XX" and y["saved_date"] is None and z["saved_date"] is None)
    st = A._stops["r_sanko_line"]
    x = A.record("r_sanko_line", st[0]["node_id"], st[-1]["node_id"], "201X-XX-XX")
    h = A.effective_hi(A.ride_of(x, x["saved_date"]))
    R.add("H4c", "범위 날짜도 멤버십과 교차 (§2.8 J)", "201X 三江線 끝 2018-03-31", f"{x['saved_date']} 끝={h}", h == "2018-03-31")
    q = A.db.execute("""SELECT s.route_id, s.node_id, s.valid_to_hi FROM route_stop s JOIN route r ON r.id=s.route_id
        WHERE s.is_stop=1 AND s.valid_to_hi<? AND r.closed=0 AND s.seq>0
          AND s.node_id NOT IN (SELECT old_node FROM node_move)
          AND s.seq<(SELECT max(seq) FROM route_stop t WHERE t.route_id=s.route_id AND t.valid_to='ongoing')
          AND EXISTS(SELECT 1 FROM route_stop t WHERE t.route_id=s.route_id AND t.seq<s.seq AND t.valid_to='ongoing' AND t.is_stop=1)
        ORDER BY s.route_id, s.seq LIMIT 1""", (A.today,)).fetchone()
    a = next(t["node_id"] for t in A._stops[q[0]] if t["valid_to"] == "ongoing" and t["is_stop"])
    x = A.record(q[0], a, q[1])
    r1, r2 = A.ride_of(x, None, (True, True)), A.ride_of(x, None, (True, False))
    r1["created"] = r2["created"] = A.today
    R.add("L2b", "잘린 끝은 승하차가 아니므로 정차 기간으로 깎지 않음 (§2.8 J, M)", "밟음이면 폐역 전, 통과면 만든 날",
          f"{A.effective_hi(r1)} / {A.effective_hi(r2)}", A.effective_hi(r1) < q[2] and A.effective_hi(r2) == A.today)
    t = lambda r, n: {x[0] for x in A.db.execute("SELECT other_line_id FROM route_link WHERE route_id=? AND kind='transfer' AND seq=(SELECT seq FROM route_stop WHERE route_id=? AND node_id=? LIMIT 1)", (r, r, n))}
    g = "r_ginza_line"
    R.add("H6", "묶음이 사슬이어도 근거 없는 쌍은 환승이 아님", "日本橋에 総武本線 없음, 銀座에 日比谷線 있음",
          sorted(x for x in t(g, "n_nihombashi_tokyo_metro") if "soubu" in x) + sorted(x for x in t(g, "n_ginza") if "hibiya" in x),
          not any("soubu" in x for x in t(g, "n_nihombashi_tokyo_metro")) and any("hibiya" in x for x in t(g, "n_ginza")))
    a = A.find_node("r_nagoya_main_line", "金山")
    p1 = {q["node"]: q["state"] for q in A.picker("r_nagoya_main_line", "1985-06-01")}
    p2 = {q["node"]: q["state"] for q in A.picker("r_nagoya_main_line", "2000-06-01")}
    R.add("H5", "名鉄 金山橋(~1989)/金山(1989~) 역 교체", "1985 金山橋만, 2000 金山만", f"1985 橋={p1.get('n_kanayamabashi')} 金山={p1.get('n_kanayama_meitetsu')} / 2000 橋={p2.get('n_kanayamabashi')} 金山={p2.get('n_kanayama_meitetsu')}",
          p1.get("n_kanayamabashi") == "open" and p1.get("n_kanayama_meitetsu") != "open" and p2.get("n_kanayama_meitetsu") == "open", "金山(_2) valid_from=1944-09-01. 1989 개설 역인데 앞 시대에도 선택됨")

    # ---- I. 공동 사용 ---------------------------------------------------
    jr = A.expand("r_iida_line", "n_toyohashi", "n_kozakai", T)
    me = A.expand("r_nagoya_main_line", "n_toyohashi_meitetsu", "n_ina", T)
    rj, rm = A.ride_of(jr, T), A.ride_of(me, T)
    uj = {A.unit_of(l, e, "on") for l, e in rj["edges"]}
    um = {A.unit_of(l, e, "on") for l, e in rm["edges"]}
    c = A.completion([rm], "current", "on", set(jr["edges"]))
    R.add("I1", "名鉄·JR 豊橋~平井信号場 공동 사용", "飯田線 4.4 / 名古屋本線 豊橋→伊奈 5.0, 단위 겹치지 않음, 名鉄 탑승이 JR 분모를 채우지 않음", f"{jr['km']} / {me['km']} / 교집합 {len(uj & um)} / JR 분모 채움 {c['num_km']}/{c['den_km']}",
          approx(jr["km"], 4.4) and approx(me["km"], 5.0) and not (uj & um) and c["num_km"] == 0)
    na = A.expand("r_namboku_line_tokyo_metro", "n_meguro_tokyo_metro", "n_shirokane_takanawa_tokyo_metro", T)
    # 目黒–白金高輪는 공용 선로 한 벌(역 노드·칸 하나, SHARED_TRACK U03, 8회차 W1b)
    mi = A.expand("r_mita_line", "n_meguro_tokyo_metro", "n_shirokane_takanawa_tokyo_metro", T)
    ra = A.ride_of(na, T)
    # 공용 선로는 칸이 하나라 칸으로 자르면 두 노선 단위가 함께 잡힌다. 南北線 탑승이 三田線 단위(노선, 칸)를 채우지 않는지 단위로 본다
    _xu = {A.unit_of(l, e, "on") for l, e in ra["edges"]} & {A.unit_of("l_mita_line", e, "on") for e in mi["edges"]}
    c = dict(num_km=round(sum(A.denom_units("current", "on")[k]["km"] for k in _xu if k in A.denom_units("current", "on")), 1))
    gs = A.db.execute("SELECT group_id FROM node WHERE id IN ('n_meguro_tokyo_metro','n_meguro_tokyu_railways')").fetchall()
    tk = A.expand("r_meguro_line", "n_meguro_tokyu_railways", "n_den_en_chofu", T)
    shared = set(tk["edges"]) & set(na["edges"])
    R.add("I2", "東京メトロ·都営 目黒~白金高輪 공유, 東急 目黒線", "두 사업자 각 2.3km·단위 분리, 東急 目黒線은 선로 공유 없음(目黒 역 group만 같음)", f"南北線 {na['km']} 三田線 {mi['km']}, 교차 크레딧 {c['num_km']}, 東急 공유 edge {len(shared)}, group {sorted({g[0] for g in gs})}",
          approx(na["km"], 2.3) and approx(mi["km"], 2.3) and c["num_km"] == 0 and not shared and len({g[0] for g in gs}) == 1,
          "요청의 '東京メトロ·東急 目黒線 공유'는 실제로 東京メトロ·都営 구간. 東急 目黒線과 南北線은 직통만")
    c1 = A.expand("r_chuo_main_line", "n_kanayama_chuo_main", "n_nagoya", T)
    t1 = A.expand("r_tokaido_main_line", "n_kanayama_chuo_main", "n_nagoya", T)
    cc = A.completion([A.ride_of(c1, T)], "current", "on", set(t1["edges"]))
    R.add("I3", "JR 예외 金山~名古屋 (§2.7 표)", "中央本線 3.3·東海道本線 3.3 각각 집계, 中央本線 탑승은 東海道本線 미승", f"{c1['km']} / {t1['km']} / 다른 edge {set(c1['edges']) != set(t1['edges'])} / 교차 {cc['num_km']}",
          approx(c1["km"], 3.3) and approx(t1["km"], 3.3) and cc["num_km"] == 0)

    # ---- J. 옛 사철 폐선 ------------------------------------------------
    r = "r_nomi_line"
    a, b = "n_tsurugi", "n_shin_terai"
    x = A.record(r, a, b, None)
    rd = A.ride_of(x)
    es = set(x["edges"])
    cur, al = A.completion([rd], "current", "on", es), A.completion([rd], "alltime", "on", es)
    cl = {q[0] for q in A.db.execute("SELECT DISTINCT class FROM denominator_unit WHERE edge_id IN (%s)" % ",".join("?" * len(es)), tuple(es))}
    tot = A.completion([rd], "alltime", "on")
    # N05 대조가 끝나 처음부터 사철이던 2000년 전 폐선도 분모 안이다 (판 2026-11-04.2)
    R.add("J1", "사철 폐선 北陸鉄道 能美線(1980)", "기록 ok, 등급 normal, 현행 분모 0, 역대 분모와 전체 분자에 그 km", f"{x['status']} {x['km']}km, class={cl}, 현행 {cur['den_km']}, 역대 {al['den_km']}, 전체 분자 {tot['num_km']}",
          x["status"] == "ok" and cl == {"normal"} and cur["den_km"] == 0 and approx(al["den_km"], x["km"]) and approx(tot["num_km"], x["km"]))
    x = A.record(r, a, b, "1975-06-01")
    R.add("J1b", "能美線 1975 날짜 입력", "1980까지 영업이라 날짜 유지", f"{x['status']} saved={x['saved_date']} km={x['km']}", x["saved_date"] == "1975-06-01")
    r = "r_umeda_freight_line"
    x = A.record(r, "n_shin_osaka", "n_fukushima_osaka_loop", T)
    rd = A.ride_of(x)
    es = set(x["edges"])
    cl = {q[0] for q in A.db.execute("SELECT DISTINCT class FROM denominator_unit WHERE edge_id IN (%s)" % ",".join("?" * len(es)), tuple(es))}
    tot = A.completion([rd], "current", "on")
    R.add("J2", "별선 梅田貨物線", "기록 ok, 등급 extra, 분모·분자 0", f"{x['status']} {x['km']}km class={cl}, 전체 분자 {tot['num_km']}", x["status"] == "ok" and cl == {"extra"} and tot["num_km"] == 0)

    # ---- K. 연도 분모 ---------------------------------------------------
    rnd = random.Random(20261101)
    years = sorted(rnd.sample(range(1970, 2027), 3))
    # 승계 끔 단위의 km는 단위(승계 묶음, 칸)의 모든 행이 그 시대 노선일 때만 그 시대 km다(compile 단위 규칙). 국철→3섹은 끔에서 단위가 나뉘어 늘 그렇고,
    # 사철 사이 이관(西鉄 北九州線→筑豊電鉄 黒崎駅前–熊西)은 끔에서도 한 단위라 지금 km다 (7회차 2026-11-14)
    off_rows = collections.defaultdict(list)
    for e, rows in A._attrs.items():
        for a in rows:
            off_rows[a["carryover_group"], e].append(a)
    def off_km(g, e):
        rows = off_rows[g, e]
        era = [A.era[(a["line_id"], e)] for a in rows if (a["line_id"], e) in A.era]
        return era[0] if era and len(era) == len(rows) else A.km[e]
    for y in years:
        units_on, units_off = {}, {}
        for e, rows in A._attrs.items():
            for a in rows:
                if a["denominator_class"] != "normal":
                    continue
                if year_certain(y, a["valid_from"], a["valid_to"]):
                    units_on[a["lineage_id"] + ":" + e] = A.km[e]
                    units_off[a["carryover_group"] + ":" + e] = off_km(a["carryover_group"], e)
        t = A.db.execute("SELECT km,unit_count FROM denominator WHERE scope='all' AND basis=? AND carryover='on'", (str(y),)).fetchone()
        dn = A.denom_units(str(y), "off")
        R.add(f"K{y}", f"{y}년 분모 재계산 (edge_attr, 하루라도 영업)", f"denominator 표 {t[0]}km {t[1]}단위와 일치", f"켬 {round(sum(units_on.values()), 1)}km {len(units_on)}단위 / 끔 {round(sum(units_off.values()), 1)}km {len(units_off)}단위 (끔은 표 없음, unit 합 {round(sum(v['km'] for v in dn.values()), 1)})",
              approx(round(sum(units_on.values()), 1), t[0]) and len(units_on) == t[1] and approx(round(sum(units_off.values()), 1), round(sum(v["km"] for v in dn.values()), 1)))
    for b, c in (("current", "on"), ("alltime", "on"), ("alltime", "off")):
        t = A.db.execute("SELECT km,unit_count FROM denominator WHERE scope='all' AND basis=? AND carryover=?", (b, c)).fetchone()
        u = A.denom_units(b, c)
        R.add(f"K-{b}-{c}", f"{b}/{c} 분모 표 = denominator_unit 합", f"{t[0]}km {t[1]}단위", f"{round(sum(v['km'] for v in u.values()), 1)}km {len(u)}단위", approx(round(sum(v["km"] for v in u.values()), 1), t[0]) and len(u) == t[1])
    rows = A.db.execute("SELECT carryover,basis,count(*) FROM denominator WHERE scope='all' GROUP BY 1").fetchall()
    c = A.db.execute("SELECT count(*) FROM denominator WHERE carryover='off' AND basis<>'alltime'").fetchone()[0]
    R.add("K-off", "승계 끔의 현행·연도 분모 행 (§2.8 E 두 방식 미리 계산)", "denominator에 off 행 존재", f"off 행은 alltime 1개뿐, 현행·연도 off 행 {c}개", None, "denominator_unit에서 합산하면 됨. 우회 가능")
    y70 = [k for k, v in A.denom_units("1970", "on").items() if edtf_range(v["valid_from"])[0] is None]
    u69 = A.undecided_units(1969, "on")
    nul69 = [k for k, v in A.units.items() if k[1] == "on" and v["class"] == "normal" and v["valid_from"] is None and overlaps_year(1969, None, edtf_range(v["valid_to"])[1])]
    R.add("K-null", "개업일 NULL 단위의 연도 분모 (§5.4 판정 불가)", "확실한 해에만 분모. 애매하면 판정 불가로 분리", f"1970년 분모의 개업일 NULL 단위 {len(y70)}개, 1969년 판정 불가 {len(u69)}단위 {round(sum(v['km'] for v in u69.values()), 1)}km (개업일 NULL {len(nul69)})", not y70 and all(k[0] in u69 for k in nul69), "denominator가 NULL을 '항상 영업'으로 세어 연도 분모가 부풀려짐")

    save = A.today
    A.today = "2018-03-31"
    k1 = round(sum(v["km"] for v in A.denom_units("current", "on").values()), 1)
    A.today = "2018-04-01"
    k2 = round(sum(v["km"] for v in A.denom_units("current", "on").values()), 1)
    A.today = save
    R.add("K-date", "현행 분모가 오늘 날짜로 바뀌는가 (§2.8 J)", "2018-03-31→04-01 차이 108.1 (三江線)", f"{k1} → {k2}, 차이 {round(k1 - k2, 1)}", approx(k1 - k2, 108.1), "denominator 표의 current는 한 값이라 denominator_unit으로 계산해야 함")

    # ---- L. 기록 승계 부가 ----------------------------------------------
    r = "r_shinetsu_main_line"
    a = A.db.execute("SELECT DISTINCT carryover_group FROM edge_attr WHERE edge_id=?", (A.edge_between("n_karuizawa", "n_naka_karuizawa"),)).fetchall()
    R.add("L1", "§2.8 E 표: 국철→JR 유지, JR→타사 새 값", "o_japanese_national_railways·o_jr_east 같은 group, しなの 다른 group", [tuple(q) for q in a], len(a) == 2)
    ride = dict(date=None, edges=A.ride_of(A.record("r_sanko_line", "n_gotsu", "n_miyoshi", None))["edges"], created="2026-11-01")
    R.add("L2", "§2.8 J 날짜 없는 기록 유효 끝", "2018-03-31", A.effective_hi(ride), A.effective_hi(ride) == "2018-03-31")

    es = {e for e, rows in A._attrs.items() if any(a["line_id"] == "l_sassho_line" for a in rows)}
    c, a = A.completion([], "current", "on", es), A.completion([], "alltime", "on", es)
    R.add("L3", "노선 상세 삿쇼선 (§3.3 예시)", "현행 28.9 / 역대 111.4", f"{c['den_km']} / {a['den_km']}", c["den_km"] == 28.9 and a["den_km"] == 111.4)

    # ---- M. 이름 --------------------------------------------------------
    ln = "l_etsumi_nan_line"
    t = [("n_kamono", ln, "1980-06-01", "加茂野口"), ("n_tomika", ln, "1980-06-01", "加茂野"),
         ("n_kamono", "l_etsumi_nan_line_nagaragawa", "2020-06-01", "加茂野"), ("n_tomika", "l_etsumi_nan_line_nagaragawa", "2020-06-01", "富加")]
    got = [(n, l, d, A.name(n, l, d)) for n, l, d, _ in t]
    R.add("M1", "越美南線 1980 (노선 고유 이름)", "加茂野口 / 加茂野, 長良川鉄道로는 加茂野 / 富加", [g[3] for g in got], all(g[3] == w[3] for g, w in zip(got, t)))
    ko = A.name("n_kamono", ln, "1980-06-01", "ko")
    R.add("M1b", "같은 역의 한국어 노선 고유 이름", "加茂野口 → 카모노구치 계열", ko, ko != "카모노", "ja는 옛 이름인데 ko는 현행 이름을 복사")
    nm = A.name("n_saga_arashiyama", "l_sanin_main_line", "1980-06-01")
    R.add("M2", "山陰本線 嵯峨嵐山 1980 (1994 개명)", "嵯峨", nm, nm == "嵯峨", "name.valid_from/valid_to가 전 행 NULL. '날짜' 단계가 동작하지 않음")
    nm = A.name("n_oomaenishi", None) if False else None
    z = A.db.execute("SELECT count(*) FROM nm.name WHERE valid_from IS NOT NULL OR valid_to IS NOT NULL").fetchone()[0]
    R.add("M3", "날짜 붙은 이름 행", "개명 역마다 1행 이상", f"{z}행", z > 0)
    nm = A.name("n_naganohara_kusatsuguchi", "l_naganohara_line"), A.name("n_naganohara_kusatsuguchi", "l_agatsuma_line")
    R.add("M4", "長野原線 시절 長野原 (노선 고유)", "長野原 / 長野原草津口", nm, nm == ("長野原", "長野原草津口"))
    nm = A.name("n_naganohara_kusatsuguchi", "l_agatsuma_line", "1985-06-01")
    R.add("M4b", "吾妻線 1985의 長野原 (1991 개명)", "長野原", nm, nm == "長野原", "노선 고유 행이 長野原線에만 있어 吾妻線 1971~1991은 현행 이름")
    n1 = A.db.execute("SELECT entity_id FROM nm.name WHERE entity_type='node' AND lang='ja' AND text LIKE 'とうきょうスカイツリー%' AND line_id IS NULL").fetchone()
    nm = A.name(n1[0], None, "2005-06-01") if n1 else None
    nm2 = A.name("n_meitetsu_nagoya", "l_nagoya_main_line", "2000-06-01")
    R.add("M4c", "그 밖의 개명: 業平橋(~2012), 新名古屋(~2005)", "業平橋 / 新名古屋", (nm, nm2), (nm, nm2) == ("業平橋", "新名古屋"))
    q = A.db.execute("SELECT count(*) FROM nm.search WHERE search MATCH '\"業 平 橋\"'").fetchone()[0]
    R.add("M4d", "옛 역 이름으로 검색", "業平橋 검색 결과 있음", f"{q}건", q > 0)
    a = A.db.execute("SELECT count(*) FROM nm.search WHERE search MATCH '\"北 り あ す 線\"'").fetchone()[0]
    b = A.db.execute("SELECT count(*) FROM nm.alias WHERE kind='old_title' OR kind='search'").fetchone()[0]
    c = A.db.execute("SELECT count(*) FROM nm.name WHERE entity_type='route'").fetchone()[0]
    R.add("M5", "옛 노선 이름 검색·계통 칩 이름", "北リアス線 검색 가능, 계통 이름 있음", f"北リアス線 {a}건, old_title/search alias {b}건, route name {c}건", a > 0 and c > 0, "칩 글자는 alias(noritsubushi)나 양 끝 역으로 조립해야 함")


# ============================================================== 전수 점검 ==
def sweep(A, R):
    print("\n=== 전수 점검 ===")
    T = A.today
    # S1 계통 사슬 연속성
    gaps, unused, kmdiff = [], collections.Counter(), []
    for rid, stops in A._stops.items():
        cands = collections.defaultdict(list)
        deg = collections.Counter()
        for _, e, a, b in A.route_edges(rid):
            if not cands[frozenset((a, b))]:
                deg[a] += 1
                deg[b] += 1
            cands[frozenset((a, b))].append(e)
        used = set()
        # 기점 너머 옛 자리는 음수 km다 (지금 끝 역 기준, 高松（旧）)
        cum = (stops[0]["km_cum"] or 0.0) if stops else 0.0
        # 나란한 옛 선로(이설)의 역은 새 선로의 역과 km 순으로 섞여 있다. 바로 다음 역과 이어지지 않으면
        # 세 칸 안의 역과 이어지는지 보고, 건너뛴 역은 앞뒤 세 칸 안의 역과 따로 이어져야 한다
        i = 0
        skipped = []
        while i < len(stops) - 1:
            p = stops[i]
            js = [j for j in range(i + 1, min(i + 4, len(stops))) if cands.get(frozenset((p["node_id"], stops[j]["node_id"])))]
            # 막다른 옛 자리(仙人峠·立山仮·新潟(旧))는 km 순으로 사이에 끼어도 사슬의 다음 역이 아니다. 갈래가 둘 이상인 역을 먼저 고르고, 모두 막다른 역이면 뒤쪽 것을 고른다
            nonleaf = [j for j in js if deg[stops[j]["node_id"]] > 1]
            j = nonleaf[0] if nonleaf else (js[-1] if js else None)
            if j is None:
                # 남은 역이 모두 앞쪽 역에 매달린 막다른 옛 자리면 끊김이 아니다 (아래 건너뛴 역 검사로 이웃을 확인)
                rest = stops[i + 1:]
                if all(deg[x["node_id"]] == 1 for x in rest):
                    skipped += rest
                    break
                gaps.append((rid, p["seq"], p["node_id"], stops[i + 1]["node_id"]))
                break
            q = stops[j]
            es = cands[frozenset((p["node_id"], q["node_id"]))]
            used.update(es)
            skipped += stops[i + 1:j]
            # 본선 계통의 옛 선로(route_only가 그 계통) 칸은 km_cum이 지금 km 축 위 자리라 옛 선로 길이와 다를 수 있다 (옛 선로 비율 배치, compile _alt_scale)
            oldhop = A.routes[rid]["role"] == "main" and all(A.edges[x]["route_only"] == rid for x in es)
            if j == i + 1 and oldhop:
                cum = q["km_cum"] or cum
            elif j == i + 1:
                # 노선 시대 km(edge_km_era)가 있으면 계통 누계도 그 값으로 센다 (compile이 km_cum을 era km로 낸다)
                era = (A.routes[rid]["line_id"], es[0]) in A.era
                cum += A.era[(A.routes[rid]["line_id"], es[0])] if era else A.km[es[0]]
                # era km를 역 사이에 비율로 나눈 칸은 0.1 반올림 차이가 날 수 있다 (伊田線·丸森線 등)
                if abs(cum - (q["km_cum"] or 0)) > (0.151 if era else 0.051):
                    kmdiff.append((rid, q["seq"], round(cum, 1), q["km_cum"]))
            cum = q["km_cum"] or cum
            i = j
        for x in skipped:
            k = stops.index(x)
            # 막다른 옛 자리는 갈라진 역이 몇 칸 떨어져 있어도 된다 (新潟(旧)은 白山에서 갈라지고 사이에 白山(旧)·上所·新潟)
            win = stops if deg[x["node_id"]] == 1 else stops[max(0, k - 3):k + 4]
            nb = [y for y in win if y is not x and cands.get(frozenset((x["node_id"], y["node_id"])))]
            if not nb:
                gaps.append((rid, x["seq"], x["node_id"], None))
            for y in nb:
                used.update(cands[frozenset((x["node_id"], y["node_id"]))])
        # 본선 계통의 옛 선로(route_only가 그 계통) 사슬과 같은 두 역을 바로 잇는 지금 칸은 옛 자리 역이 km 순으로 사이에 끼어
        # 위 사슬 걷기에서 건너뛰어진다. 두 끝이 그 옛 선로 사슬로도 이어지면 그날 경로로 쓰인다 (田立: 南木曽–田立 新線와 南木曽–田立(旧)–田立)
        if A.routes[rid]["role"] == "main":
            oadj = collections.defaultdict(set)
            for _, e, a_, b_ in A.route_edges(rid):
                if A.edges[e]["route_only"] == rid:
                    oadj[a_].add(b_)
                    oadj[b_].add(a_)
            def _oldpath(x, y):
                seen, st_ = {x}, [x]
                while st_:
                    n_ = st_.pop()
                    for m_ in oadj[n_]:
                        if m_ == y:
                            return True
                        if m_ not in seen:
                            seen.add(m_)
                            st_.append(m_)
                return False
            for _, e, a_, b_ in A.route_edges(rid):
                if e not in used and A.edges[e]["route_only"] != rid and _oldpath(a_, b_):
                    used.add(e)
        for _, e, _, _ in A.route_edges(rid):
            if e not in used:
                unused[rid] += 1
    R.add("S1", "route_stop 순서대로 이으면 route_edge가 있는가", "끊김 0", f"끊김 {len(gaps)}건 {gaps[:5]}", not gaps)
    R.add("S2", "route_stop 사슬에 안 쓰이는 route_edge", "0 (있으면 어떤 경로로도 못 탐)", f"{sum(unused.values())}구간 / {len(unused)}계통 {list(unused.items())[:6]}", not unused)
    R.add("S3", "km_cum과 edge_km 누적 차이", "0.1 초과 없음", f"{len(kmdiff)}건 {kmdiff[:5]}", not kmdiff)
    mis = 0
    for rid, res in A._route_edges.items():
        order = [e for _, e in res]
        if len(A._stops[rid]) - 1 != len(order):
            mis += 1
    R.add("S3b", "route_edge.seq와 route_stop.seq가 나란한가", "앱이 seq를 믿어도 되는지", f"edge 수 ≠ stop-1 계통 {mis}개 (이설 평행 edge가 뒤에 붙음)", None, "route_edge에 기간이 없고 순서도 안 맞으니 날짜별 그래프로 펼쳐야 함")

    # S4 무작위 왕복: 선택기 → 펼치기
    rnd = random.Random(7)
    rids = list(A.routes)
    stat = collections.Counter()
    bad, cut = [], []
    for i in range(4000):
        rid = rnd.choice(rids)
        d = rnd.choice([T, f"{rnd.randint(1970, 2026)}-{rnd.randint(1, 12):02d}-15", None])
        rows = [q for q in A.picker(rid, d) if q["selectable"]]
        if len(rows) < 2:
            stat["선택 2역 미만"] += 1
            continue
        p, q = rnd.sample(rows, 2)
        if p["node"] == q["node"]:
            continue
        x = A.expand_any(rid, p["node"], q["node"], d)
        stat[x["status"] + (":" + x.get("reason", "") if x.get("reason") else "")] += 1
        if x["status"] == "ok" and d is not None and not A.routes[rid]["closed"] and not p["is_extension"] and not q["is_extension"]:
            if p["km_on_date"] is not None and q["km_on_date"] is not None and abs(abs(p["km_on_date"] - q["km_on_date"]) - x["km"]) > 0.11:
                bad.append((rid, d, p["name"], q["name"], x["km"], p["km_on_date"], q["km_on_date"]))
        if x["status"] == "invalid" and x.get("reason") == "no-path-ever":
            bad.append((rid, d, p["name"], q["name"], "no-path-ever"))
        if x["status"] == "invalid" and x.get("reason") != "no-path-ever":
            cut.append((rid, d, p["name"], q["name"]))
    R.add("S4", "무작위 4000회: 선택 가능한 두 역을 펼치기", "ok 또는 needs_input. 끊김은 중간 폐지·운휴로 설명", dict(stat), not any(x[-1] == "no-path-ever" for x in bad),
          f"km 불일치·경로 없음 {len(bad)}건 {bad[:4]}. 그날 끊긴 사례 {cut[:5]}")
    # S5 운행 계통
    # 판마다 부분이 이어지고 각 부분이 날짜 없이 펼쳐지는가. 그날의 운휴(肥薩線 등)는 정의의 끊김이 아니다
    res = {}
    has_ed = A.db.execute("SELECT 1 FROM sqlite_master WHERE name='service_edition'").fetchone()
    for (sid,) in A.db.execute("SELECT id FROM service").fetchall():
        rows = A.db.execute("SELECT * FROM service_part WHERE service_id=? ORDER BY " + ("edition, seq" if has_ed else "seq"), (sid,)).fetchall()
        gaps, prev = [], None
        _grp = lambda n: A.db.execute("select coalesce(group_id, id) from node where id=?", (n,)).fetchone()[0] if n else n
        for p in rows:
            ed = p["edition"] if has_ed else 0
            # 같은 역 묶음(group)의 다른 노드로 넘어가도 이어진다 (compile _sv_grp와 같음, 長崎 住吉)
            if prev is not None and prev[0] == ed and _grp(prev[1]) != _grp(p["from_node"]):
                gaps.append((ed, prev[1], p["from_node"]))
            x = A.expand(p["route_id"], p["from_node"], p["to_node"], None)
            if x["status"] not in ("ok", "needs_input"):
                gaps.append((ed, p["route_id"], p["from_node"], p["to_node"], x["status"], x.get("reason")))
            prev = (ed, p["to_node"])
        res[sid] = gaps
    badsvc = {k: v for k, v in res.items() if v}
    R.add("S5", f"운행 계통 {len(res)}개 이어짐", "전부 이어짐", f"끊김 {len(badsvc)}개 {badsvc}", not badsvc)
    # S6 단위 대응
    miss = 0
    for e, rows in A._attrs.items():
        for a in rows:
            # 여객 영업 이력이 없는 화물선(hidden)은 DB에만 두어 단위가 없다 (사용자 결정 2026-11-09)
            if a["denominator_class"] == "hidden":
                continue
            for c, k in (("on", a["lineage_id"]), ("off", a["carryover_group"])):
                if (k + ":" + e, c) not in A.units:
                    miss += 1
    R.add("S6", "edge_attr 모든 행이 denominator_unit에 단위가 있는가", "누락 0", miss, miss == 0)
    # S7 등급 규칙
    by_unit = collections.defaultdict(list)
    for e, rows in A._attrs.items():
        for a in rows:
            by_unit[(a["lineage_id"], e)].append(a)
    wrong_out, old_norm = [], []
    for (lg, e), rows in by_unit.items():
        legal0 = [l["legal_abolition"] for l in A._life[e] if l["legal_abolition"]]
        # §4.6 법적 폐지일 기준. 폐선 뒤 같은 칸이 다시 열려 같은 계보로 이어지면(open+continues: 湯の川線 1945 폐지·1959 재개업, 八栗ケーブル) 단위의 끝은
        # 옛 폐지일이 아니라 단위 행들의 가장 늦은 끝이다. 둘 중 늦은 쪽을 쓴다 (9회차 S)
        hi = max(legal0 + [a["valid_to_hi"] or MAXD for a in rows])
        cl = {a["denominator_class"] for a in rows}
        legal = max((l["legal_abolition"] or "") for l in A._life[e]) if A._life[e] else ""
        # N05 대조가 끝나 새로 들어온 폐선도 분모 안이다 (판 2026-11-04.2). outside는 대조 중인 범위가 생길 때만 쓴다
        if "outside" in cl:
            wrong_out.append((lg, e, hi))
        if "normal" in cl and hi < FLOOR:
            old_norm.append((lg, e, hi, rows[0]["line_id"], legal))
    R.add("S7", "§4.6 등급: N05 대조가 끝나 1950~1969 국철·JR과 처음부터 사철이던 1950~1999 폐선도 분모 안 (outside 0)", "규칙 위반 0", f"outside {len(wrong_out)}, 기준일 전 폐지인데 normal {len(old_norm)} {sorted({x[3] for x in old_norm})[:6]}",
          not wrong_out and not old_norm)
    # S8 이관 옛 계통의 정차역
    miss = []
    for rid, stops in A._stops.items():
        line = A.routes[rid]["line_id"]
        for s in stops:
            if s["is_stop"]:
                continue
            others = [q for q2 in A.db.execute("SELECT route_id,valid_from FROM route_stop WHERE node_id=? AND is_stop=1", (s["node_id"],)).fetchall() for q in [q2]]
            if others and all(o[1] == s["valid_to"] for o in others):
                miss.append((rid, A.name(s["node_id"]), s["valid_to"]))
    R.add("S8", "이관 전 계통에서 is_stop=0, 이관 후 계통에서만 정차로 시작하는 역", "대부분 이관 뒤 신설역이어야 함. 표본 확인", f"{len(miss)}건 {miss[:10]}", None,
          "이관일에 맞춰 valid_from이 잘리므로 실제 개업일을 DB에서 알 수 없음")
    # S9 선택 상태 모순
    c = collections.Counter()
    samples = {}
    for d in ("1975-06-15", "1990-06-15", "2005-06-15", "2020-06-15", T):
        for rid in A.routes:
            for q in A.picker(rid, d):
                if q["state"] in ("no_edge", "line_closed"):
                    # 이설 전 선로를 같은 노선의 지선 계통(○○旧線)에 둔 곳은 그 계통에서 그날 고를 수 있으면 모순이 아니다
                    line = A.routes[rid]["line_id"]
                    if any(r2 != rid and A.routes[r2]["line_id"] == line and any(x["node"] == q["node"] and x["selectable"] for x in A.picker(r2, d)) for r2 in A.routes):
                        continue
                    st = next(x for x in A._picks[rid] if x["seq"] == q["seq"])
                    key = q["state"] + ("/valid_to NULL" if st["valid_to"] is None else "")
                    c[key] += 1
                    samples.setdefault(key, (rid, d, q["name"]))
    R.add("S9", "역은 있는데 그날 인접 선로가 없음 (route_stop 기간과 edge 기간 불일치)", "폐지일 모름(valid_to NULL) 말고 0", f"{dict(c)} 예: {samples}", all(k.endswith("NULL") for k in c),
          "valid_to NULL 11행은 선로 상태로 걸러져 선택 불가로 나옴. route_stop만 보면 영업 중으로 오판")
    # S10 숨은 끝
    hid = []
    # 여객 영업 이력이 없는 화물선(rule_class hidden)은 기록할 수 없어 끝 확장이 필요 없다 (9회차 F)
    _hidl = {l for (l,) in A.db.execute("SELECT id FROM line WHERE rule_class='hidden'")}
    for rid, r in A.routes.items():
        if r["line_id"] in _hidl:
            continue
        for end in (r["from_node"], r["to_node"]):
            if A.node_kind.get(end) != "station":
                hid.append((rid, A.line_name(r["line_id"]), end, A.node_kind.get(end)))
    psg = [h for h in hid if "kamotsu" not in h[0]]
    noext = [h for h in hid if not A.routes[h[0]]["extend_to"]]
    R.add("S10", "계통 끝이 숨은 노드인데 extend_to 없음", "숨은 끝마다 extend_to", f"{len(hid)}개 끝(여객 {len(psg)}개) 중 extend_to 없는 끝 {len(noext)}: {sorted({h[1] for h in noext})}", not noext)
    # S11 closed
    dup = []
    for rid, st in A._stops.items():
        ns = [s["node_id"] for s in st]
        if len(ns) != len(set(ns)) and not A.routes[rid]["closed"]:
            dup.append(rid)
    ring = [rid for rid in A.routes if A.ring_nodes(rid) and not A.routes[rid]["closed"]]
    R.add("S11", "고리가 있는데 closed=0 인 계통 / 같은 역 두 번", "0", f"같은 역 두 번 {dup[:6]}, 고리 {[(r, A.line_name(A.routes[r]['line_id'])) for r in ring][:8]}, closed_from 값 {A.db.execute('SELECT count(*) FROM route WHERE closed_from IS NOT NULL').fetchone()[0]}개", not dup)
    # S12 continue
    rows = A.db.execute("SELECT route_id,seq,other_line_id,valid_from,valid_to FROM route_link WHERE kind='continue'").fetchall()
    ends = 0
    for r in rows:
        st = A._stops[r["route_id"]]
        seqs = [s["seq"] for s in st]
        # 계통 끝 너머 확장 행에 단 끝 이어짐(吾妻橋線 本所吾妻橋, 9회차 L)은 계통 끝 바깥이라 끝 이음이다
        if not any(s["seq"] == r["seq"] for s in st) and any(s["seq"] == r["seq"] and s["is_extension"] for s in A._picks[r["route_id"]]):
            ends += 1
            continue
        node = next(s["node_id"] for s in st if s["seq"] == r["seq"])
        ln = A.routes[r["route_id"]]["line_id"]
        gone = [e for _, e, x, y in A.route_edges(r["route_id"]) if node in (x, y) and A.attr_on(e, ln, T, follow_lineage=False)[0] is None]
        # 오늘 고를 수 있는 역의 첫·끝이면 지금 소속 구간의 끝이다 (新潟 옛 경로의 大形: 앞쪽은 숨은 분기점을 지나 닫힌 구간)
        live = [q["seq"] for q in A.picker(r["route_id"], T) if q["selectable"]]
        # 날짜가 있는 이음은 그 이음이 생긴 첫날의 선택기로 본다. 이미 끝난 이음(옛 경로 계통과의 continue, 三岐線 1931~1985)과
        # 그때는 끝 역이었다가 연장으로 지나가는 역이 된 직통(시기별 끝 역, compile.era_end: 泉岳寺 1968·綾瀬 1971·盛岡 1997)
        past = False
        if r["valid_from"] and re.fullmatch(r"\d{4}-\d{2}-\d{2}", r["valid_from"]):
            # 기준일(1950-01-01) 전 날짜는 선택기가 날짜 모름으로 보므로 기준일부터 본다
            then = [q["seq"] for q in A.picker(r["route_id"], max(r["valid_from"], "1950-01-01")) if q["selectable"]]
            past = bool(then) and r["seq"] in (min(then), max(then))
            # 그날 이 역에 닿는 이 계통 칸 한쪽이 그 노선에 아직 없으면 그날 이 역은 끝이다. 계통이 두 토막으로 나뉜 때(拝島線 1958–1962:
            # 小平–萩山과 小川–玉川上水 사이 萩山–小川 개업 전)에는 선택기 첫·끝 역만으로는 가운데 끝 역을 못 본다 (11회차 S2, 4회차 kanto_1-003)
            if not past:
                d_ = max(r["valid_from"], "1950-01-01")
                es_ = [e for _, e, x, y in A.route_edges(r["route_id"]) if node in (x, y)]
                past = len(es_) >= 2 and any(A.attr_on(e, ln, d_, follow_lineage=False)[0] is None for e in es_)
        if r["seq"] in (seqs[0], seqs[-1]) or gone or past or (live and r["seq"] in (min(live), max(live))):
            ends += 1
    R.add("S12", "continue 행이 끝 역이나 지금 소속 구간의 끝에 있는가 (§2.9 표 1행)", "표시 결정표: 중간 역의 continue는 분기로 그림. 1행 이하", f"{len(rows)}행 중 {ends}", len(rows) - ends <= 1, "중간 역의 continue는 표시 결정표에 맞는 행이 없음")
    # S13 junction 기간
    z = A.db.execute("SELECT count(*), sum(valid_from IS NULL), sum(valid_to='ongoing') FROM junction").fetchone()
    R.add("S13", "junction 기간", "그날 유효한 행을 고를 수 있어야 함", f"{z[0]}행 모두 valid_from NULL·valid_to ongoing={z[2]}", None, "1985년 화면에도 나중에 생긴 분기가 그대로 나옴")
    p = [l for row in A.picker("r_sekihoku_main_line", "1975-06-15") for l in row["links"] if l["kind"] == "branch"][:3]
    fut = 0
    first = {}
    for e, rows in A._attrs.items():
        for a in rows:
            first[a["line_id"]] = min(first.get(a["line_id"], "9999"), a["valid_from_lo"] or "0000")
    for r in A.db.execute("SELECT * FROM route_link WHERE kind='branch'"):
        if first.get(r["other_line_id"], "0000") > "1990-01-01" and (edtf_range(r["valid_from"])[0] or "0000") < first[r["other_line_id"]]:
            fut += 1
    R.add("S13c", "1980년대 화면에 나중에 생긴 노선의 분기가 나오는가", "그날 없던 노선은 표시 규칙을 따름", f"분기 행 중 상대 노선 개업이 1990 이후인 {fut}행이 valid_from NULL이라 그대로 통과", fut == 0, "상대 노선의 edge_attr 기간으로 앱이 거를 수 있음")
    br = A.db.execute("SELECT count(*), sum(other_route_id IS NULL), sum(valid_from IS NULL) FROM route_link WHERE kind='branch'").fetchone()
    R.add("S13b", "route_link 분기 행", "계통까지 지정(other_route_id)", f"{br[0]}행 중 other_route_id NULL {br[1]}, valid_from NULL {br[2]}", None, "line의 main 계통으로 대체 가능")
    # S14 재해 운휴 복구 사례
    known = [("山田線 宮古→釜石 2015", "r_yamada_line", "宮古", "釜石", "2015-01-01"),
             ("常磐線 竜田→富岡 2015", "r_joban_line", "竜田", "富岡", "2015-01-01"),
             ("石巻線 浦宿→女川 2013", "r_ishinomaki_line", "浦宿", "女川（旧）", "2013-06-01"),
             ("仙石線 高城町→陸前小野 2013", "r_senseki_line", "高城町", "陸前小野", "2013-06-01"),
             ("只見線 会津川口→只見 2015", "r_tadami_line", "会津川口", "只見", "2015-06-01"),
             ("名松線 家城→伊勢奥津 2012", "r_meisho_line", "家城", "伊勢奥津", "2012-06-01"),
             ("日高本線 鵡川→様似 2018", "r_hidaka_main_line", "鵡川", "様似", "2018-06-01"),
             ("豊肥本線 肥後大津→立野 2018", "r_hohi_main_line", "肥後大津", "立野", "2018-06-01"),
             ("リアス線 小本→田野畑 2012", "r_rias_line", "岩泉小本", "田野畑", "2012-06-01"),
             ("肥薩線 八代→人吉 오늘", "r_hisatsu_line", "八代", "人吉", T),
             ("津軽線 蟹田→三厩 오늘", "r_tsugaru_line", "蟹田", "三厩", T),
             ("米坂線 今泉→坂町 오늘", "r_yonesaka_line", "今泉", "坂町", T),
             ("美祢線 厚狭→長門市 오늘", "r_mine_line", "厚狭", "長門市", T)]
    res = {}
    for name, rid, a, b, d in known:
        na, nb = A.find_node(rid, a), A.find_node(rid, b)
        if not na or not nb:
            res[name] = f"이름 못 찾음 {a if not na else b}"
            continue
        x = A.expand(rid, na[-1], nb[-1], d)
        es = x["edges"]
        if not es:
            opts = [o for o in A.relocation_options(rid, na[-1], nb[-1]) if o["as_of"] <= d]
            es = A.expand(rid, na[-1], nb[-1], max(opts, key=lambda o: o["as_of"])["as_of"])["edges"] if opts else A.expand(rid, na[-1], nb[-1], None, resolve_unknown=True)["edges"]
        res[name] = dict(collections.Counter(A.life_on(e, d)[0] for e in es))
    # 운휴 중이면 suspended, 재개 없이 폐지·이설로 끝났으면 운휴 시작으로 소급해 closed다(日高本線·石巻線 옛 女川·仙石線 옛 선로·津軽線 中小国–三厩, 결정 122)
    caught = sum(1 for v in res.values() if isinstance(v, dict) and (v.get("suspended") or v.get("closed")) and not v.get("open"))
    R.add("S14", "재해 불통 13건이 edge_life에 있는가", "전 구간 suspended, 폐지·이설로 끝난 곳은 소급 closed", f"{caught}/13 잡힘. {res}", caught == len(known),
          "suspended 행은 폐지로 끝난 구간(SVC 표 7개 노선)에만 있음. 복구됐거나 아직 불통인 구간은 없음")
    # S15 archive 연결
    bad = 0
    for r in A.db.execute("SELECT * FROM archive_stop"):
        # 열람 전용 노선에 단 역은 계통이 없다 (결정 133)
        if r["archive_line_id"]:
            continue
        if r["route_id"] not in A.routes:
            bad += 1
            continue
        ns = [s["node_id"] for s in A._stops[r["route_id"]]]
        # 앞 자리는 같은 계통의 열람 전용 역 ID도 된다 (DESIGN §4.5 「after는 앞의 열람 전용 역 ID도 쓸 수 있습니다」, 9회차 S 기준일 전 정차의 열람 전용)
        ns += [x[0] for x in A.db.execute("SELECT id FROM archive_stop WHERE route_id=?", (r["route_id"],))]
        if r["after_id"] not in ns and r["after_id"] is not None:
            bad += 1
    R.add("S15", "archive_stop의 위치가 계통 노드를 가리키는가", "0 위반", f"{bad}건 / 442", bad == 0)
    # S16 ko 이름
    z = A.db.execute("""SELECT count(*) FROM nm.name a JOIN nm.name b ON a.entity_id=b.entity_id AND a.entity_type=b.entity_type AND a.line_id=b.line_id AND a.lang='ja' AND b.lang='ko'
        JOIN nm.name c ON c.entity_id=a.entity_id AND c.lang='ja' AND c.line_id IS NULL
        JOIN nm.name d ON d.entity_id=a.entity_id AND d.lang='ko' AND d.line_id IS NULL
        WHERE a.line_id IS NOT NULL AND a.text<>c.text AND b.text=d.text AND COALESCE(a.kana,'')<>COALESCE(c.kana,'')""").fetchone()[0]
    q = A.db.execute("SELECT count(*) FROM nm.name WHERE line_id IS NOT NULL AND lang='ja'").fetchone()[0]
    R.add("S16", "노선 고유 ja가 다른데 ko는 현행 그대로", "읽기가 같은 표기 변형만", f"{z}건 / 노선 고유 ja {q}건", None, "2026-11-01 19건 전수 확인: 大阪（うめきた）, 明知/明智처럼 읽기가 같아 ko가 같음")


def sweep2(A, R):
    T = A.today
    # S17 scope 행 재계산
    cur = collections.Counter()
    for e, rows in A._attrs.items():
        for a in rows:
            if a["denominator_class"] == "normal" and state_on(T, a["valid_from_lo"], a["valid_from_hi"], a["valid_to_lo"], a["valid_to_hi"]) in ("yes", "maybe"):
                cur[a["line_id"]] += A.km[e]
                cur[a["operator_id"]] += A.km[e]
    bad = []
    n = 0
    for r in A.db.execute("SELECT scope,km FROM denominator WHERE scope<>'all'"):
        n += 1
        if abs(cur.get(r["scope"], 0) - r["km"]) > 0.051:
            bad.append((r["scope"], r["km"], round(cur.get(r["scope"], 0), 1)))
    R.add("S17", f"사업자·노선별 현행 분모 {n}행 재계산", "edge_attr 합과 일치", f"불일치 {len(bad)} {bad[:6]}", not bad)
    # S18 공개 노드
    z = A.db.execute("SELECT kind,count(*) FROM node WHERE id IN (SELECT id FROM node_public) GROUP BY 1").fetchall()
    h = A.db.execute("SELECT count(*) FROM node WHERE kind<>'station'").fetchone()[0]
    hn = A.db.execute("SELECT count(*) FROM nm.name WHERE entity_type='node' AND entity_id IN (SELECT id FROM node WHERE kind<>'station')").fetchone()[0]
    R.add("S18", "node_public에 숨은 노드가 없는가", f"station만, 숨은 {h}개는 이름도 없음", f"{[tuple(q) for q in z]}, 숨은 노드 이름 {hn}행", all(q[0] == "station" for q in z) and hn == 0)
    # S19 이름 채움
    miss = {}
    for lang in ("ja", "ko", "en"):
        miss[lang] = A.db.execute("SELECT count(*) FROM node_public p WHERE NOT EXISTS (SELECT 1 FROM nm.name n WHERE n.entity_type='node' AND n.entity_id=p.id AND n.lang=? AND n.line_id IS NULL)", (lang,)).fetchone()[0]
    l = A.db.execute("SELECT count(*) FROM line p WHERE (SELECT count(DISTINCT lang) FROM nm.name n WHERE n.entity_type='line' AND n.entity_id=p.id)<2").fetchone()[0]
    R.add("S19", "공개 노드·노선 이름 언어별 빠짐", "0", f"node {miss}, line {l}", not any(miss.values()) and l == 0)
    # S20 숨은 분기의 부모 화면 표시
    miss, have = [], 0
    # 여객 영업 이력이 없는 화물선(rule_class hidden)은 앱 어디에도 나오지 않는다. 부모 화면에 분기 줄이 없어야 맞다 (9회차 F)
    _hid = {l for (l,) in A.db.execute("SELECT id FROM line WHERE rule_class='hidden'")}
    for rid, r in A.routes.items():
        if r["line_id"] in _hid:
            continue
        for end in (r["from_node"], r["to_node"]):
            if A.node_kind.get(end) == "station":
                continue
            parents = [p for p, st in A._stops.items() if p != rid and A.routes[p]["line_id"] != r["line_id"] and any(s["node_id"] == end for s in st)]
            for p in parents:
                c = A.db.execute("SELECT count(*) FROM route_link WHERE route_id=? AND other_line_id=?", (p, r["line_id"])).fetchone()[0]
                if c or A.routes[p]["extend_to"] or r["extend_to"]:
                    have += 1
                else:
                    miss.append((A.line_name(A.routes[p]["line_id"]), A.line_name(r["line_id"])))
    R.add("S20", "숨은 노드에서 갈라지는 노선이 부모 노선 화면에 나오는가", "모두 표시", f"표시 {have}, 없음 {len(miss)} {sorted(set(miss))[:10]}", not miss, "at_edge 행이 0이라 부모 화면에 분기 줄이 없음. 숨은 노드 공유로 앱이 유도 가능")


# ============================================================= 스키마 비교 ==
DESIGN_14_1 = {
    "node": "id kind group_id pref export_name",
    "station_group": "id",
    "hub": "id",
    "hub_member": "hub_id node_id valid_from valid_to source verified",
    "junction": "id line_id other_line_id other_route_id node_id edge_id side continue valid_from valid_to source verified",
    "lineage_stage": "lineage_id seq line_id from_node to_node valid_from valid_to",
    "archive_stop": "id line_id route_id after_id before_id opened closed km source legal_abolition archive_line_id seq",
    "archive_line": "id line_id at_node opened closed source legal_abolition",
    "node_position": "node_id lat lon quality checked valid_from valid_to",
    "node_public": "(view)",
    "route": "id line_id role from_node to_node via_nodes closed closed_from extend_to map_coverage",
    "route_edge": "route_id seq edge_id valid_from valid_to",
    "route_stop": "route_id seq node_id km_cum is_stop is_extension valid_from valid_to",
    "route_link": "route_id seq other_line_id other_route_id kind side at_edge other_node next_stop_node terminal_node flow flow_source valid_from valid_to",
    "route_link_reverse": "route_id seq other_line_id next_stop_node valid_from valid_to",
    "edge": "id from_node to_node seed_line route_only geometry_quality geometry_source",
    "edge_life": "edge_id valid_from valid_to status last_service legal_abolition close_reason",
    "edge_km": "edge_id km valid_from valid_to",
    "edge_attr": "id edge_id line_id operator_id lineage_id carryover_group denominator_class valid_from valid_to",
    "service": "id closed valid_from valid_to",
    "service_edition": "service_id edition valid_from valid_to all_stops",
    "service_part": "service_id edition seq route_id from_node to_node",
    "service_stop": "service_id edition seq node_id",
    "edge_link": "edge_id successor_edge_id kind",
    "line": "id type rule_class",
    "operator": "id category",
    "closed_section": "line_id from_node to_node km abolished last_service map_visible",
    "denominator": "scope basis carryover valid_from valid_to km unit_count",
    "denominator_unit": "unit_key carryover km class certainty valid_from valid_to",
    "id_redirect": "entity_type old_id context_line new_ids dataset_version",
    "coverage": "line_id period grade",
}
DESIGN_14_2 = {
    "name": "entity_type entity_id lang text kana source reading_source source_title checked line_id valid_from valid_to",
    "alias": "entity_type entity_id lang text kind",
    "search": "(fts)",
}


def schema_diff(A):
    print("\n=== 스키마 차이 (§14.1, §14.2) ===")
    out = []
    for db, design in (("main", DESIGN_14_1), ("nm", DESIGN_14_2)):
        actual = {r[0]: r[1] for r in A.db.execute(f"SELECT name,type FROM {db}.sqlite_master WHERE type IN ('table','view')")}
        for t, cols in design.items():
            if t not in actual:
                out.append((t, "테이블 없음", cols))
                continue
            if cols.startswith("("):
                continue
            real = [r[1] for r in A.db.execute(f"PRAGMA {db}.table_info('{t}')")]
            miss = [c for c in cols.split() if c not in real]
            ext = [c for c in real if c not in cols.split() and not c.endswith(("_lo", "_hi"))]
            if miss or ext:
                out.append((t, "컬럼 없음: " + " ".join(miss) if miss else "", ("설계에 없음: " + " ".join(ext)) if ext else ""))
            has_period = "valid_from" in real
            if has_period and "valid_from_lo" not in real:
                out.append((t, "lo/hi 없음 (설계 §14 머리말)", ""))
        for t in actual:
            if t not in design and not t.startswith(("search_", "sqlite_")):
                out.append((t, "설계에 없는 테이블", ""))
    for row in out:
        print("  ", row)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--no-sweep", action="store_true")
    ap.add_argument("--master")
    ap.add_argument("--names")
    args = ap.parse_args()
    A = App(args.master, args.names)
    R = Report()
    scenarios(A, R)
    if not args.no_sweep:
        sweep(A, R)
        sweep2(A, R)
    diff = schema_diff(A)
    c = collections.Counter(r["verdict"] for r in R.rows)
    print("\n=== 요약 ===", dict(c))
    for r in R.rows:
        if r["verdict"] == "FAIL":
            print("FAIL", r["id"], r["title"])
    if args.json:
        json.dump(dict(rows=R.rows, schema=diff), open(args.json, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    if c.get("FAIL"):
        raise SystemExit(f"앱 시뮬 FAIL {c['FAIL']}")


if __name__ == "__main__":
    main()
