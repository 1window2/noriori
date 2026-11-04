import 'package:flutter/material.dart';

import '../../../i18n/strings.g.dart';

/// 데이터 출처. 라이선스가 요구하는 표기이기도 하다 (DESIGN §13).
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t.sources;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(t.intro, style: text.bodyMedium),
          const SizedBox(height: 16),
          for (final (name, use, terms, url) in [
            (t.n02.name, t.n02.use, t.n02.terms, 'https://nlftp.mlit.go.jp/ksj/'),
            (t.n05.name, t.n05.use, t.n05.terms, 'https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N05-2024.html'),
            (t.n03.name, t.n03.use, t.n03.terms, 'https://nlftp.mlit.go.jp/ksj/'),
            (
              t.stationDatabase.name,
              t.stationDatabase.use,
              t.stationDatabase.terms,
              'https://github.com/Seo-4d696b75/station_database',
            ),
            (t.wikipedia.name, t.wikipedia.use, t.wikipedia.terms, 'https://creativecommons.org/licenses/by-sa/4.0/'),
            (
              t.openStreetMap.name,
              t.openStreetMap.use,
              t.openStreetMap.terms,
              'https://www.openstreetmap.org/copyright',
            ),
            (t.wikidata.name, t.wikidata.use, t.wikidata.terms, 'https://www.wikidata.org/'),
            (t.namuwiki.name, t.namuwiki.use, t.namuwiki.terms, 'https://namu.wiki/'),
            (t.noritsubushi.name, t.noritsubushi.use, t.noritsubushi.terms, 'https://www.noritsubushi.org/'),
            (t.openFreeMap.name, t.openFreeMap.use, t.openFreeMap.terms, 'https://openfreemap.org/'),
            (t.noto.name, t.noto.use, t.noto.terms, 'https://openfontlicense.org/'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(name, style: text.titleSmall),
                  Text(use, style: text.bodyMedium),
                  Text(terms, style: text.bodySmall),
                  SelectableText(url, style: text.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
