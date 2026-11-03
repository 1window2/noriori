# -*- coding: utf-8 -*-
# Wikidata(CC0)에서 일본 철도역의 날짜·읽기·좌표를 한 번에 받는다
import sys,json,urllib.parse,urllib.request,time
OUT=sys.argv[1]
Q='''SELECT ?s ?ja ?ko ?en ?kana ?open ?close ?dis ?inc ?coord ?lineLabel WHERE {
 ?s wdt:P31/wdt:P279* wd:Q55488; wdt:P17 wd:Q17.
 OPTIONAL{?s rdfs:label ?ja FILTER(lang(?ja)="ja")}
 OPTIONAL{?s rdfs:label ?ko FILTER(lang(?ko)="ko")}
 OPTIONAL{?s rdfs:label ?en FILTER(lang(?en)="en")}
 OPTIONAL{?s wdt:P1814 ?kana}
 OPTIONAL{?s wdt:P1619 ?open}
 OPTIONAL{?s wdt:P3999 ?close}
 OPTIONAL{?s wdt:P576 ?dis}
 OPTIONAL{?s wdt:P571 ?inc}
 OPTIONAL{?s wdt:P625 ?coord}
 OPTIONAL{?s wdt:P81 ?line. ?line rdfs:label ?lineLabel FILTER(lang(?lineLabel)="ja")}
}'''
d=urllib.parse.urlencode({'query':Q,'format':'json'}).encode()
r=urllib.request.Request('https://query.wikidata.org/sparql',data=d,headers={'User-Agent':'noriori-data/0.1 (personal open-source rail record app)','Accept':'application/sparql-results+json','Content-Type':'application/x-www-form-urlencoded'})
for a in range(3):
    try:
        b=urllib.request.urlopen(r,timeout=200).read();open(OUT,'wb').write(b);print('ok',len(b));break
    except Exception as e:
        print('retry',e);time.sleep(30)
