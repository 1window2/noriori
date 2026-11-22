import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/theme/tokens.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'session_lines.dart';
import 'session_painters.dart';

/// 접힌 선형(같은 노선의 다른 시기 선형)의 그림 (DESIGN §8.3, 목업 「같은 노선 이어 그리기」).
///
/// 접힌 선형의 줄은 일반 줄과 같은 타일로 그리되 그림만 [foldShift]만큼 오른쪽 칸으로 옮긴다. 글자는 본선 역과 같은 줄이다.
/// 본선 줄기는 그 아래를 그대로 지나간다
const double foldShift = SelectorRuler.nodeX - SelectorRuler.trunkX;

/// 접힌 선형 줄기의 굵기 (분기선과 같다).
const double foldWidth = 2.5;

/// 접힌 선형 안 줄 하나의 그림 정보.
final class FoldCtx {
  const FoldCtx({
    required this.fold,
    required this.trunk,
    required this.mainPass,
    required this.color,
  });

  final FoldLine fold;
  final FoldTrunk trunk;

  /// 그 자리를 지나가는 본선 줄기.
  final TrunkPiece? mainPass;
  final Color color;
}

/// 본선 줄 위에 더 그리는 것: 돌아오는 접힌 선형이 옆을 지나가거나(pass), 그 역으로 돌아온다(rejoin).
final class FoldDecor {
  FoldDecor();

  /// 옆을 지나가는 접힌 선형의 색.
  Color? pass;

  /// 이 역으로 돌아오는 접힌 선형의 색.
  Color? rejoin;

  /// 역 하나뿐인 선형으로 꺾여 나가는 곡선 (아래로 가면 거짓).
  ({Color color, bool up})? single;

  /// 접힌 줄 머리로 가는 어깨 곡선.
  ({Color color, bool up})? shoulder;
}

/// 목록에 펼친 줄과 줄마다의 그림 정보.
final class FoldLayout {
  FoldLayout(this.lines, this.ctx, this.decor, this.open, this.toggle);

  final List<SelectorLine> lines;
  final Map<SelectorLine, FoldCtx> ctx;
  final Map<SelectorLine, FoldDecor> decor;

  /// 펼친 접힌 줄의 열쇠
  final Set<String> open;
  final void Function(FoldLine fold) toggle;
}

/// 접힌 선형 열쇠 (열고 닫음을 기억한다).
String foldKey(FoldLine f) => '${f.fold.anchor}:${f.fold.up}:${f.fold.period}';

Color foldColor(FoldLine f, AppTokens tokens) =>
    f.fold.rows.rows.any((row) => row.selectable)
    ? tokens.lineUnridden
    : tokens.selectorGone;

/// [lines]의 접힌 줄을 목록에 펼친다. 역이 하나뿐인 선형은 늘 펼치고 머리가 없다.
/// 본선으로 돌아오는 선형은 옆 본선 역과 km 순서대로 섞는다
FoldLayout layoutFolds(
  List<SelectorLine> lines,
  Set<String> open,
  TrunkStyle main,
  RecordSessionState state,
  AppTokens tokens, {
  required void Function(FoldLine fold) toggle,
}) {
  final out = <SelectorLine>[];
  final ctx = LinkedHashMap<SelectorLine, FoldCtx>.identity();
  final decor = LinkedHashMap<SelectorLine, FoldDecor>.identity();
  FoldDecor d(SelectorLine l) => decor.putIfAbsent(l, FoldDecor.new);
  // 본선 역 줄 순서 (돌아오는 선형을 섞을 때)
  final stops = [
    for (final l in lines)
      if (l is StopLine) l,
  ];
  int stopIndexOf(int seq) => stops.indexWhere((s) => s.row.seq == seq);
  // 돌아오는 선형: 본선 줄 사이에 끼울 자리를 먼저 정한다
  final inserts = LinkedHashMap<SelectorLine, List<SelectorLine>>.identity();
  final before = LinkedHashMap<SelectorLine, List<SelectorLine>>.identity();
  for (final line in lines) {
    if (line is! FoldLine) continue;
    final f = line.fold;
    final color = foldColor(line, tokens);
    final isOpen = f.single || open.contains(foldKey(line));
    final anchorStop = stops[stopIndexOf(f.anchor)];
    final rejoinAt = f.rejoin == null ? -1 : stopIndexOf(f.rejoin!);
    final trunk = FoldTrunk(
      state,
      tokens,
      line,
      color: color,
      rejoins: f.rejoin != null,
    );
    FoldCtx c(SelectorLine l, TrunkPiece? pass) =>
        FoldCtx(fold: line, trunk: trunk, mainPass: pass, color: color);
    final inner = line.lines;
    if (f.single) {
      d(anchorStop).single = (color: color, up: f.up);
    } else {
      d(anchorStop).shoulder = (color: color, up: f.up);
    }
    if (!isOpen) {
      // 닫힌 머리: 머리만. 돌아오는 선형이면 머리부터 돌아오는 역까지 옆을 지나간다
      continue;
    }
    // 접힌 줄 머리 쪽 본선 칸(아래로 붙으면 붙는 역 아래, 위로 붙으면 위)이 그 아래로 지나간다
    for (final l in inner) {
      ctx[l] = c(l, main.gap(f.up ? anchorStop.index - 1 : anchorStop.index));
    }
    if (rejoinAt < 0) continue;
    // km 순서대로 본선 역 사이에 끼운다. 접힌 줄 안의 역 아닌 줄은 앞 역을 따라간다
    final groups = <List<SelectorLine>>[];
    for (final l in inner) {
      if (l is StopLine || groups.isEmpty) {
        groups.add([l]);
      } else {
        groups.last.add(l);
      }
    }
    final a = stopIndexOf(f.anchor);
    var k = a + 1;
    for (final g in groups) {
      final km = g.first is StopLine ? (g.first as StopLine).row.kmCum : null;
      while (km != null &&
          k < rejoinAt &&
          (stops[k].row.kmCum ?? double.infinity) < km) {
        k++;
      }
      final target = k < rejoinAt ? stops[k] : stops[rejoinAt];
      (before[target] ??= []).addAll(g);
      // 끼어든 자리(target 역 바로 위 칸)의 본선 줄기가 그 아래로 지나간다
      for (final l in g) {
        ctx[l] = c(l, main.gap(target.index - 1));
      }
    }
    inserts[line] = const [];
  }
  for (final line in lines) {
    if (line is FoldLine) {
      // 아래로 붙으면 머리 아래로, 위로 붙으면 머리 위로 편다. 머리는 늘 붙는 역 바로 옆이다 (목업과 같다)
      final shownInner = !inserts.containsKey(line) && (line.fold.single || open.contains(foldKey(line)));
      if (line.fold.up && shownInner) out.addAll(line.lines);
      if (!line.fold.single) out.add(line); // 머리
      if (!line.fold.up && shownInner) out.addAll(line.lines);
      continue;
    }
    if (before[line] case final list?) out.addAll(list);
    out.add(line);
  }
  // 돌아오는 선형: 머리(또는 꺾여 나간 역)부터 돌아오는 역까지 본선 줄 옆을 지나간다. 분기 원 근처에서는 흐려진다
  for (final line in lines) {
    if (line is! FoldLine || line.fold.rejoin == null) continue;
    final color = foldColor(line, tokens);
    final start = out.indexWhere(
      (l) => l is StopLine && l.row.seq == line.fold.anchor,
    );
    final end = out.indexWhere(
      (l) => l is StopLine && l.row.seq == line.fold.rejoin,
    );
    if (start < 0 || end <= start) continue;
    for (var k = start + 1; k < end; k++) {
      final l = out[k];
      if (ctx.containsKey(l) || identical(l, line)) continue;
      if (l is FoldLine) continue;
      d(l).pass = color;
    }
    d(out[end]).rejoin = color;
  }
  return FoldLayout(out, ctx, decor, open, toggle);
}

/// 접힌 선형 안의 줄기. 선형 자기 칸의 상태로 칠하고, 머리(위)와 돌아오는 역(아래) 쪽 끝도 잇는다
class FoldTrunk extends TrunkStyle {
  FoldTrunk(
    RecordSessionState state,
    AppTokens tokens,
    this.fold, {
    required this.color,
    required this.rejoins,
  }) : super(state, const [], tokens);

  final FoldLine fold;
  final Color color;
  final bool rejoins;

  @override
  TrunkPiece? gap(int gap) {
    final rows = fold.fold.rows;
    final last = rows.rows.length - 1;
    // 머리 쪽 끝은 머리로 잇고, 반대쪽 끝은 본선으로 돌아올 때만 잇는다. 위로 붙으면 머리가 아래쪽 끝이다
    final headSide = fold.fold.up ? gap >= last : gap == -1;
    final farSide = fold.fold.up ? gap == -1 : gap >= last;
    if (headSide) return TrunkPiece(color, foldWidth);
    if (farSide) return rejoins ? TrunkPiece(color, foldWidth) : null;
    if (gap < 0) return null;
    final open = gap >= rows.openGaps.length || rows.openGaps[gap];
    return TrunkPiece(
      open && rows.rows.any((row) => row.selectable)
          ? color
          : tokens.selectorGone,
      foldWidth,
    );
  }
}

/// 줄 그림을 접힌 선형 칸으로 옮기고, 그 아래로 지나가는 본선 줄기와 본선 줄 위의 접힌 선형 장식을 그린다
class FoldPainter extends CustomPainter {
  FoldPainter(
    this.inner, {
    this.ctx,
    this.decor,
    required this.centerY,
    this.branchY,
    this.shiftOnly = false,
    this.padded = false,
  });

  /// 옮기기만 한다 (접힌 선형 안 줄의 괄호 겹그림)
  final bool shiftOnly;

  /// 줄이 통째로 [foldShift]만큼 옮겨져 있다 (분기·끝 이어짐·안내 줄). 그림은 옮기지 않고 지나가는 본선 줄기만 제자리에 그린다
  final bool padded;
  final CustomPainter inner;
  final FoldCtx? ctx;
  final FoldDecor? decor;
  final double centerY;

  /// 분기 줄의 원 높이. 지나가는 접힌 선형은 그 근처에서 흐려진다 (분기가 우선)
  final double? branchY;

  Paint _p(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;

  @override
  void paint(Canvas canvas, Size size) {
    const tx = SelectorRuler.trunkX,
        qx = SelectorRuler.nodeX,
        r = SelectorRuler.bend;
    if (shiftOnly) {
      canvas.save();
      canvas.translate(foldShift, 0);
      inner.paint(canvas, size);
      canvas.restore();
      return;
    }
    final c = ctx;
    if (c != null) {
      final pass = c.mainPass;
      // 본선 줄기와 같은 그리기(점선·이관 점선 박자 포함)로 긋는다
      if (padded) {
        canvas.save();
        canvas.translate(-foldShift, 0);
        paintTrunk(canvas, pass, 0, size.height);
        canvas.restore();
      } else {
        paintTrunk(canvas, pass, 0, size.height);
      }
      canvas.save();
      if (!padded) canvas.translate(foldShift, 0);
      inner.paint(canvas, size);
      canvas.restore();
      return;
    }
    // 접힌 선형 장식(옆을 지나는 선·돌아오는 곡선·「]」 곡선)은 역 줄 그림보다 먼저 그린다. 끝이 역 노드 아래로 들어가 노드가 덮는다
    final dd = decor;
    if (dd == null) {
      inner.paint(canvas, size);
      return;
    }
    final y = centerY;
    if (dd.pass case final color?) {
      final by = branchY;
      if (by == null) {
        canvas.drawLine(
          const Offset(qx, 0),
          Offset(qx, size.height),
          _p(color, foldWidth),
        );
      } else {
        // 분기 원 근처 몇 픽셀은 흐려진다
        canvas.drawLine(
          const Offset(qx, 0),
          Offset(qx, by - 16),
          _p(color, foldWidth),
        );
        _fade(canvas, Offset(qx, by - 16), Offset(qx, by - 7), color);
        _fade(canvas, Offset(qx, by + 16), Offset(qx, by + 7), color);
        canvas.drawLine(
          Offset(qx, by + 16),
          Offset(qx, size.height),
          _p(color, foldWidth),
        );
      }
    }
    if (dd.rejoin case final color?) {
      final path = Path()
        ..moveTo(qx, 0)
        ..lineTo(qx, y - r)
        ..arcToPoint(Offset(qx - r, y), radius: const Radius.circular(r))
        ..lineTo(tx, y);
      canvas.drawPath(path, _p(color, foldWidth));
    }
    if (dd.single case final s?) {
      final path = Path()
        ..moveTo(tx, y)
        ..lineTo(qx - r, y)
        ..arcToPoint(
          Offset(qx, s.up ? y - r : y + r),
          radius: const Radius.circular(r),
          clockwise: !s.up,
        )
        ..lineTo(qx, s.up ? 0 : size.height);
      canvas.drawPath(path, _p(s.color, foldWidth));
    }
    inner.paint(canvas, size);
  }

  void _fade(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = _p(color, foldWidth)
      ..shader = LinearGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromPoints(from, to.translate(0.01, 0.01)));
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant FoldPainter old) => true;
}

/// 접힌 줄 그림 정보를 아래 타일에 건넨다
class FoldView extends InheritedWidget {
  const FoldView({super.key, required this.layout, required super.child});

  final FoldLayout layout;

  static FoldLayout? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldView>()?.layout;

  @override
  bool updateShouldNotify(FoldView old) => !identical(old.layout, layout);
}

/// 타일의 그림판을 접힌 선형 칸으로 옮기거나 본선 줄 위 장식을 더한다. 해당 없으면 그대로다
CustomPainter foldPaint(
  BuildContext context,
  SelectorLine line,
  CustomPainter painter, {
  double centerY = 24,
  double? branchY,
}) {
  final layout = FoldView.of(context);
  if (layout == null) return painter;
  final c = layout.ctx[line];
  final d = layout.decor[line];
  if (c == null && d == null) return painter;
  return FoldPainter(
    painter,
    ctx: c,
    decor: d,
    centerY: centerY,
    branchY: branchY,
    padded: c != null && foldPadded(line),
  );
}

/// 접힌 선형 안에서 글자까지 통째로 옮기는 줄
bool foldPadded(SelectorLine line) => line is BranchLine || line is EndLine || line is NoticeLine;

/// 접힌 줄 머리로 가는 붙는 역의 어깨 곡선 색. 해당 없으면 null
Color? foldShoulder(
  BuildContext context,
  SelectorLine line, {
  required bool up,
}) {
  final s = FoldView.of(context)?.decor[line]?.shoulder;
  return s != null && s.up == up ? s.color : null;
}

/// 접힌 줄 머리 「▸ 기간 · 다음 역 › 마지막 역 · n역」. 누르면 펼치고 접는다 (DESIGN §8.3)
class FoldHeadTile extends ConsumerWidget {
  const FoldHeadTile({super.key, required this.line, required this.trunk, this.next, this.prev});

  final FoldLine line;
  final TrunkPiece? trunk;
  final SelectorLine? next;
  final SelectorLine? prev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = FoldView.of(context);
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(recordSessionProvider);
    final f = line.fold;
    final open = layout?.open.contains(foldKey(line)) ?? false;
    final color = foldColor(line, tokens);
    final rows = f.rows.rows;
    // 위로 붙으면 목록 아래쪽(붙는 역 쪽)이 다음 역이다
    final near = f.up ? rows.last : rows.first;
    final far = f.up ? rows.first : rows.last;
    final t = context.t.session;
    final label = [
      if (f.period.isNotEmpty) f.period,
      '${state.nameOf(near.node)} › ${state.nameOf(far.node)}',
    ].join('  ');
    const centerY = 22.0;
    // 같은 쪽 바깥에 본선의 분기·끝 이어짐 줄이 더 있을 때만 줄기를 잇는다. 접힌 선형 안의 줄은 따지지 않는다
    final outer = f.up ? prev : next;
    final stacked = (outer is BranchLine || outer is EndLine) && !(layout?.ctx.containsKey(outer) ?? false);
    return Semantics(
      button: true,
      expanded: open,
      label: '$label, ${t.foldStops(n: rows.length)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => layout?.toggle(line),
        child: CustomPaint(
          painter: _FoldHeadPainter(
            BranchPainter(
              goneColor: tokens.selectorGone,
              trunk: trunk,
              color: color,
              stem: color,
              through: tokens.lineUnridden,
              background: tokens.surface,
              up: f.up,
              stacked: stacked,
              centerY: centerY,
            ),
            color: color,
            open: open,
            rejoins: f.rejoin != null,
            up: f.up,
            centerY: centerY,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 12, 12, 12),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      open ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: text.bodyMedium?.copyWith(color: tokens.textMuted),
                  ),
                  TextSpan(
                    text: '  ${t.foldStops(n: rows.length)}',
                    style: text.bodySmall?.copyWith(color: tokens.textClosed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 머리 그림: 분기와 같은 곡선과 원에, 펼쳤거나 본선으로 돌아오면 원에서 선형 쪽으로 줄기가 이어진다
class _FoldHeadPainter extends CustomPainter {
  _FoldHeadPainter(
    this.branch, {
    required this.color,
    required this.open,
    required this.rejoins,
    required this.up,
    required this.centerY,
  });

  final BranchPainter branch;
  final Color color;
  final bool open;
  final bool rejoins;
  final bool up;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    branch.paint(canvas, size);
    if (!open && !rejoins) return;
    const qx = SelectorRuler.nodeX;
    final paint = Paint()
      ..color = color
      ..strokeWidth = foldWidth
      ..style = PaintingStyle.stroke;
    if (up) {
      canvas.drawLine(const Offset(qx, 0), Offset(qx, centerY - 5), paint);
    } else {
      canvas.drawLine(Offset(qx, centerY + 5), Offset(qx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FoldHeadPainter old) => true;
}

/// 접힌 선형 괄호의 세로선 자리: 본선 줄기와 접힌 선형 사이 (목업 88). 옮긴 그림판 안의 값이다
const double foldBracketX = 88 - foldShift;

/// 접힌 선형의 괄호 토막을 그린다 (DESIGN §8.3). 괄호가 붙는 역(머리)·돌아오는 역까지 걸치면 그 줄에서 갈고리로 끝난다
class FoldBracketOverlay extends CustomPainter {
  const FoldBracketOverlay(this.pieces, {this.nodeY, this.reach = 6});

  final List<BracketPiece> pieces;
  final double? nodeY;
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(foldShift, 0);
    paintBrackets(canvas, size, pieces, nodeY: nodeY, nodeReach: reach, bx: foldBracketX);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FoldBracketOverlay old) => old.pieces.length != pieces.length || old.nodeY != nodeY;
}

/// 접힌 선형마다 괄호 토막을 목록 줄에 나눈다. 괄호 끝이 붙는 역이면 머리 줄, 돌아오는 역이면 그 본선 역 줄에서 끝난다
Map<SelectorLine, ({List<BracketPiece> pieces, double? nodeY, double reach})> foldBrackets(
  List<SelectorLine> shown,
  List<SelectorLine> lines,
  Color Function(NoticeKind kind) colorOf,
) {
  final out = LinkedHashMap<SelectorLine, List<BracketPiece>>.identity();
  for (final fold in lines.whereType<FoldLine>()) {
    for (final notice in fold.lines.whereType<NoticeLine>()) {
      int at(BracketAnchor a) => a.seq == fold.fold.anchor
          ? shown.indexWhere((l) => identical(l, fold))
          : shown.indexWhere((l) => l is StopLine && l.row.seq == a.seq);
      final top = at(notice.top), bottom = at(notice.bottom);
      if (top < 0 || bottom <= top) continue;
      for (var i = top; i <= bottom; i++) {
        (out[shown[i]] ??= []).add(BracketPiece(color: colorOf(notice.kind), start: i == top, end: i == bottom));
      }
    }
  }
  return {
    for (final MapEntry(key: line, value: pieces) in out.entries)
      line: switch (line) {
        FoldLine() => (pieces: pieces, nodeY: pieces.any((p) => p.start) ? 27.0 : 17.0, reach: 6.0),
        StopLine(:final row) when row.seq >= 0 && pieces.any((p) => p.end && !p.start) && !row.selectable => (pieces: pieces, nodeY: 20.0, reach: 6.5),
        StopLine(:final row) => (pieces: pieces, nodeY: row.selectable ? 24.0 : 20.0, reach: row.selectable ? 11.0 : 6.5),
        _ => (pieces: pieces, nodeY: null, reach: 6.0),
      },
  };
}
