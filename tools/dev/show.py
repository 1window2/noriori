# -*- coding: utf-8 -*-
import json
r=json.load(open('build/report.json',encoding='utf-8'))
t=json.load(open('data/candidates/n_totals.json',encoding='utf-8'));o=r['operator_km']
print('mismatch',{k:(round(o.get(k,0),1),v) for k,v in t.items() if abs(o.get(k,0)-v)>.15})
print(r['errors']);print('warn',str(r.get('warnings'))[:500])
for k,v in r['error_samples'].items():print(k,str(v[:6])[:300])
g=json.load(open('data/candidates/gen_report.json',encoding='utf-8'))
print('pending',len(g['pending']),[x[2] for x in g['pending']][:120])
