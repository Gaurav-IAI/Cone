import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
    required this.conference,
    required this.person,
  });

  final Conference conference;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final days = <String, List<ScheduleItem>>{};
    for (final item in person.scheduleWith(conference)) {
      (days[item.day] ??= []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'No sessions to show yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final entry in days.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            for (var i = 0; i < entry.value.length; i++)
              _TimelineItem(
                item: entry.value[i],
                isLast: i == entry.value.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final ScheduleItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final own = item.isOwnPresentation;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.start,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    item.end,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: own ? AppColors.teal : Colors.white,
                    border: Border.all(
                      color: own ? AppColors.teal : AppColors.navyLight,
                      width: 2.5,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.outline),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: own ? const Color(0xFFE6F6F4) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: own ? AppColors.teal : AppColors.outline,
                    width: own ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (own) ...[
                      LabelChip(
                        label: item.kind == 'presentation'
                            ? 'Your presentation'
                            : 'For you',
                        icon: Icons.star_rounded,
                        background: AppColors.teal,
                        foreground: Colors.white,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.3,
                      ),
                    ),
                    if (item.venue != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.venue!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
