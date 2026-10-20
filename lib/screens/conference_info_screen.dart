import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Conference facts taken from the source workbook (MAIN sheet).
class ConferenceInfoScreen extends StatelessWidget {
  const ConferenceInfoScreen({super.key, required this.conference});

  final Conference conference;

  @override
  Widget build(BuildContext context) {
    final c = conference;
    return Scaffold(
      appBar: AppBar(title: const Text('Conference information')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat(value: '${c.totals.abstracts}', label: 'Abstracts'),
                    _Stat(value: '${c.totals.oral}', label: 'Oral'),
                    _Stat(value: '${c.totals.poster}', label: 'Poster'),
                    _Stat(
                      value: '${c.disciplines.length}',
                      label: 'Disciplines',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'ABOUT THE APP',
            child: Row(
              children: [
                ConeLogo(size: 64),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName(context),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        coneFullName,
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your companion for the congress.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'TO BE ANNOUNCED',
            child: Column(
              children: [
                for (final item in c.notInWorkbook)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(color: AppColors.navy),
                          ),
                        ),
                        const Text(
                          'To be announced',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'These details will appear here once the organisers '
                  'publish them.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'DISCIPLINES',
            child: Column(
              children: [
                for (final d in c.disciplines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${d.srNo}.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              Text(
                                '${d.abstracts} abstracts · ${d.oral} oral · '
                                '${d.poster} poster',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'CATEGORIES & PRESENTATION',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final cat in c.categories)
                      LabelChip(label: 'Category $cat'),
                    for (final type in c.presentationTypes.entries)
                      LabelChip(
                        label: '${type.key} = ${type.value}',
                        background: const Color(0xFFEFF2F6),
                        foreground: AppColors.navy,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.tealBright,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
