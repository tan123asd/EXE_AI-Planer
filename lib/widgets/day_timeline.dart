import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'calendar_event_block.dart';

class DayTimelineEvent {
  final String id;
  final String taskId;
  final int sessionIndex;
  final String title;
  final String subject;
  final DateTime start;
  final DateTime end;
  final bool isCompleted;

  DayTimelineEvent({
    required this.id,
    required this.taskId,
    required this.sessionIndex,
    required this.title,
    required this.subject,
    required this.start,
    required this.end,
    required this.isCompleted,
  });

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;
  int get durationMinutes => end.difference(start).inMinutes.clamp(0, 24 * 60);
}

class DayTimeline extends StatefulWidget {
  final DateTime selectedDate;
  final List<DayTimelineEvent> events;
  final void Function(DayTimelineEvent event)? onEventTap;

  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final double timeGutterWidth;
  final bool hideEmptyTime;

  const DayTimeline({
    super.key,
    required this.selectedDate,
    required this.events,
    this.onEventTap,
    this.startHour = 0,
    this.endHour = 24,
    this.pxPerMinute = 1.15,
    this.timeGutterWidth = 52,
    this.hideEmptyTime = false,
  });

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  late final ScrollController _scroll;
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayStartMin = widget.startHour * 60;
    final dayEndMin = widget.endHour * 60;
    final inWindow = widget.events
        .where((e) => e.endMinutes > dayStartMin && e.startMinutes < dayEndMin)
        .toList();

    // In "hide empty time" mode, we remove empty gaps and keep only a small visual
    // separator between busy blocks to make the calendar focus on tasks.
    final gapThreshold = widget.hideEmptyTime ? 1 : 120;
    final collapsedGapHeight = widget.hideEmptyTime ? 14.0 : 42.0;
    final mapper = _TimeMapper(
      dayStartMin: dayStartMin,
      dayEndMin: dayEndMin,
      busyRanges: _mergeBusyRanges(inWindow, dayStartMin, dayEndMin),
      pxPerMinute: widget.pxPerMinute,
      gapThresholdMinutes: gapThreshold,
      collapsedGapHeight: collapsedGapHeight,
    );
    final totalHeight = mapper.totalHeight;

    final layout = _layoutEvents(
      inWindow,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didAutoScroll) return;
      _didAutoScroll = true;
      final now = DateTime.now();
      final isToday = now.year == widget.selectedDate.year &&
          now.month == widget.selectedDate.month &&
          now.day == widget.selectedDate.day;
      final targetMin = isToday ? (now.hour * 60 + now.minute) : (8 * 60);
      final offset = mapper.yForMinute(targetMin.clamp(dayStartMin, dayEndMin));
      if (_scroll.hasClients) {
        _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          controller: _scroll,
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeGutter(mapper),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return Stack(
                        children: [
                          if (!widget.hideEmptyTime) _buildHourLines(mapper),
                          if (!widget.hideEmptyTime) ..._buildCollapsedGapMarkers(mapper),
                          ...layout.map(
                            (p) => _positionedEventBlock(p, mapper, width),
                          )
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeGutter(_TimeMapper mapper) {
    final hours = (widget.endHour - widget.startHour).clamp(1, 24);
    final eventTicks = widget.hideEmptyTime ? _buildEventTicks(mapper) : null;
    return SizedBox(
      width: widget.timeGutterWidth,
      height: mapper.totalHeight,
      child: Stack(
        children: (eventTicks ?? _buildHourTicks(mapper, hours + 1)).map((t) {
          return Positioned(
            top: t.top,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, t.isFirst ? 4 : -6),
                child: Text(
                  '${t.hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_HourTick> _buildEventTicks(_TimeMapper mapper) {
    // Show only times that matter: starts/ends of sessions.
    final minutesSet = <int>{};
    final dayStartMin = mapper.dayStartMin;
    final dayEndMin = mapper.dayEndMin;
    for (final e in widget.events) {
      final s = e.startMinutes.clamp(dayStartMin, dayEndMin);
      final en = e.endMinutes.clamp(dayStartMin, dayEndMin);
      minutesSet.add(s);
      minutesSet.add(en);
    }
    final minutes = minutesSet.toList()..sort();

    final ticks = <_HourTick>[];
    double? lastTop;
    for (final m in minutes) {
      final top = mapper.yForMinute(m);
      if (lastTop != null && (top - lastTop) < 18) continue;
      ticks.add(_HourTick(hour: m ~/ 60, top: top, isFirst: ticks.isEmpty));
      lastTop = top;
    }
    return ticks;
  }

  List<_HourTick> _buildHourTicks(_TimeMapper mapper, int count) {
    final ticks = <_HourTick>[];
    double? lastTop;
    for (int i = 0; i < count; i++) {
      final hour = widget.startHour + i;
      final minute = hour * 60;
      final top = mapper.yForMinute(minute);
      if (lastTop != null && (top - lastTop) < 18) continue;
      ticks.add(_HourTick(hour: hour, top: top, isFirst: i == 0));
      lastTop = top;
    }
    return ticks;
  }

  Widget _buildHourLines(_TimeMapper mapper) {
    final hours = (widget.endHour - widget.startHour).clamp(1, 24);
    final lines = <Widget>[];
    double? lastTop;
    for (int i = 0; i < hours; i++) {
      final hour = widget.startHour + i;
      final minute = hour * 60;
      final top = mapper.yForMinute(minute);
      if (lastTop != null && (top - lastTop) < 14) continue;
      lines.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      );
      lastTop = top;
    }
    return Positioned.fill(child: Stack(children: lines));
  }

  List<Widget> _buildCollapsedGapMarkers(_TimeMapper mapper) {
    final markers = <Widget>[];
    for (final seg in mapper.segments) {
      if (!seg.isCollapsedGap) continue;
      final top = seg.yStart + (seg.pixels / 2) - 9;
      final label = _formatGap(seg.endMin - seg.startMin);
      markers.add(
        Positioned(
          top: top,
          left: 8,
          right: 8,
          height: 18,
          child: Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
            ],
          ),
        ),
      );
    }
    return markers;
  }

  Widget _positionedEventBlock(
    _PlacedEvent placed,
    _TimeMapper mapper,
    double containerWidth,
  ) {
    final startMin =
        placed.event.startMinutes.clamp(mapper.dayStartMin, mapper.dayEndMin);
    final endMin =
        placed.event.endMinutes.clamp(mapper.dayStartMin, mapper.dayEndMin);
    final top = mapper.yForMinute(startMin);
    final height = (mapper.yForMinute(endMin) - top).clamp(34.0, 99999.0);

    final leftPadding = 10.0;
    final rightPadding = 10.0;
    final availableWidth = placed.laneWidth(containerWidth);
    final laneLeft = placed.laneLeft(containerWidth);

    return Positioned(
      top: top,
      left: laneLeft + leftPadding,
      width: (availableWidth - leftPadding - rightPadding).clamp(40.0, 10000.0),
      height: height,
      child: CalendarEventBlock(
        color: AppColors.subjectAccentColor(placed.event.subject),
        title: placed.event.title,
        timeRange:
            '${_hhmm(placed.event.start)}–${_hhmm(placed.event.end)}',
        isCompleted: placed.event.isCompleted,
        onTap: widget.onEventTap == null ? null : () => widget.onEventTap!(placed.event),
      ),
    );
  }

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatGap(int minutes) {
    if (minutes <= 0) return '…';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '… ${m}m gap …';
    if (m == 0) return '… ${h}h gap …';
    return '… ${h}h ${m}m gap …';
  }

  List<_MinuteRange> _mergeBusyRanges(
    List<DayTimelineEvent> events,
    int dayStartMin,
    int dayEndMin,
  ) {
    final ranges = <_MinuteRange>[];
    for (final e in events) {
      final s = e.startMinutes.clamp(dayStartMin, dayEndMin);
      final en = e.endMinutes.clamp(dayStartMin, dayEndMin);
      if (en <= s) continue;
      ranges.add(_MinuteRange(s, en));
    }
    if (ranges.isEmpty) return const [];
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_MinuteRange>[];
    var cur = ranges.first;
    for (int i = 1; i < ranges.length; i++) {
      final r = ranges[i];
      if (r.start <= cur.end) {
        cur = _MinuteRange(cur.start, r.end > cur.end ? r.end : cur.end);
      } else {
        merged.add(cur);
        cur = r;
      }
    }
    merged.add(cur);
    return merged;
  }

  List<_PlacedEvent> _layoutEvents(List<DayTimelineEvent> events) {
    if (events.isEmpty) return const [];
    events.sort((a, b) => a.start.compareTo(b.start));

    final clusters = <List<DayTimelineEvent>>[];
    List<DayTimelineEvent> current = [];
    DateTime? currentEnd;
    for (final e in events) {
      if (current.isEmpty) {
        current = [e];
        currentEnd = e.end;
        continue;
      }
      if (e.start.isBefore(currentEnd!)) {
        current.add(e);
        if (e.end.isAfter(currentEnd)) currentEnd = e.end;
      } else {
        clusters.add(current);
        current = [e];
        currentEnd = e.end;
      }
    }
    if (current.isNotEmpty) clusters.add(current);

    final placed = <_PlacedEvent>[];
    for (final cluster in clusters) {
      placed.addAll(_layoutCluster(cluster));
    }
    return placed;
  }

  List<_PlacedEvent> _layoutCluster(List<DayTimelineEvent> cluster) {
    // Greedy lane assignment.
    final lanes = <List<DayTimelineEvent>>[];
    for (final e in cluster..sort((a, b) => a.start.compareTo(b.start))) {
      int laneIndex = -1;
      for (int i = 0; i < lanes.length; i++) {
        final last = lanes[i].last;
        if (!e.start.isBefore(last.end)) {
          laneIndex = i;
          break;
        }
      }
      if (laneIndex == -1) {
        lanes.add([e]);
      } else {
        lanes[laneIndex].add(e);
      }
    }

    final totalLanes = lanes.length.clamp(1, 3); // cap visual lanes to 3
    final results = <_PlacedEvent>[];

    // We compute width at render-time using a fixed lane grid.
    // If lanes > 3, we still place extra events into last lane.
    for (int lane = 0; lane < lanes.length; lane++) {
      final visualLane = lane >= totalLanes ? totalLanes - 1 : lane;
      for (final e in lanes[lane]) {
        results.add(
          _PlacedEvent(
            event: e,
            laneIndex: visualLane,
            laneCount: totalLanes,
          ),
        );
      }
    }
    return results;
  }
}

class _PlacedEvent {
  final DayTimelineEvent event;
  final int laneIndex;
  final int laneCount;

  _PlacedEvent({
    required this.event,
    required this.laneIndex,
    required this.laneCount,
  });

  double laneLeft(double containerWidth) {
    final laneW = laneWidth(containerWidth);
    return laneIndex * laneW;
  }

  double laneWidth(double containerWidth) {
    if (laneCount <= 1) return containerWidth;
    return containerWidth / laneCount;
  }
}

class _HourTick {
  final int hour;
  final double top;
  final bool isFirst;

  _HourTick({required this.hour, required this.top, required this.isFirst});
}

class _MinuteRange {
  final int start;
  final int end;

  const _MinuteRange(this.start, this.end);
}

class _TimeSegment {
  final int startMin;
  final int endMin;
  final double pixels;
  final bool isCollapsedGap;
  final double yStart;

  const _TimeSegment({
    required this.startMin,
    required this.endMin,
    required this.pixels,
    required this.isCollapsedGap,
    required this.yStart,
  });
}

class _TimeMapper {
  final int dayStartMin;
  final int dayEndMin;
  final double pxPerMinute;
  final int gapThresholdMinutes;
  final double collapsedGapHeight;
  final List<_TimeSegment> segments;
  final double totalHeight;

  _TimeMapper({
    required this.dayStartMin,
    required this.dayEndMin,
    required List<_MinuteRange> busyRanges,
    required this.pxPerMinute,
    required this.gapThresholdMinutes,
    required this.collapsedGapHeight,
  })  : segments = _buildSegments(
          dayStartMin,
          dayEndMin,
          busyRanges,
          pxPerMinute,
          gapThresholdMinutes,
          collapsedGapHeight,
        ),
        totalHeight = _buildSegments(
          dayStartMin,
          dayEndMin,
          busyRanges,
          pxPerMinute,
          gapThresholdMinutes,
          collapsedGapHeight,
        ).fold<double>(0, (sum, s) => sum + s.pixels);

  double yForMinute(int minute) {
    final m = minute.clamp(dayStartMin, dayEndMin);
    for (final seg in segments) {
      if (m >= seg.startMin && m <= seg.endMin) {
        final len = (seg.endMin - seg.startMin).clamp(1, 24 * 60);
        final t = (m - seg.startMin) / len;
        return seg.yStart + t * seg.pixels;
      }
    }
    return 0;
  }

  static List<_TimeSegment> _buildSegments(
    int dayStartMin,
    int dayEndMin,
    List<_MinuteRange> busy,
    double pxPerMinute,
    int gapThresholdMinutes,
    double collapsedGapHeight,
  ) {
    final segs = <_TimeSegment>[];
    double y = 0;
    int cursor = dayStartMin;

    void addGap(int start, int end) {
      if (end <= start) return;
      final minutes = end - start;
      final isCollapsed = minutes >= gapThresholdMinutes;
      final pixels = isCollapsed ? collapsedGapHeight : minutes * pxPerMinute;
      segs.add(
        _TimeSegment(
          startMin: start,
          endMin: end,
          pixels: pixels,
          isCollapsedGap: isCollapsed,
          yStart: y,
        ),
      );
      y += pixels;
    }

    void addBusy(int start, int end) {
      if (end <= start) return;
      final minutes = end - start;
      final pixels = minutes * pxPerMinute;
      segs.add(
        _TimeSegment(
          startMin: start,
          endMin: end,
          pixels: pixels,
          isCollapsedGap: false,
          yStart: y,
        ),
      );
      y += pixels;
    }

    for (final r in busy) {
      final s = r.start.clamp(dayStartMin, dayEndMin);
      final e = r.end.clamp(dayStartMin, dayEndMin);
      addGap(cursor, s);
      addBusy(s, e);
      cursor = e;
    }
    addGap(cursor, dayEndMin);
    if (segs.isEmpty) {
      segs.add(
        _TimeSegment(
          startMin: dayStartMin,
          endMin: dayEndMin,
          pixels: (dayEndMin - dayStartMin) * pxPerMinute,
          isCollapsedGap: false,
          yStart: 0,
        ),
      );
    }
    return segs;
  }
}

