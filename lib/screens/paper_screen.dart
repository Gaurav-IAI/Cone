import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class PaperScreen extends StatelessWidget {
  const PaperScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final paper = p.paper!;

    return Scaffold(
      appBar: AppBar(title: const Text('Paper & authors')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: 'TITLE OF ABSTRACT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  key: const Key('paperTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (p.presentationLabel != null)
                      LabelChip(label: p.presentationLabel!),
                    if (p.category != null)
                      LabelChip(label: 'Category ${p.category}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'SUBMISSION',
            child: Column(
              children: [
                InfoRow(label: 'Submission ID', value: paper.submissionId),
                if (p.presentationLabel != null)
                  InfoRow(label: 'Presentation', value: p.presentationLabel!),
                if (p.category != null)
                  InfoRow(label: 'Category', value: p.category!),
                if (p.discipline != null)
                  InfoRow(label: 'Discipline', value: p.discipline!),
                InfoRow(
                  label: 'Soft copy',
                  value: (p.softCopy ?? false) ? 'Submitted' : 'Not submitted',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'ABSTRACT',
            child: paper.abstractText != null
                ? Text(paper.abstractText!, style: const TextStyle(height: 1.5))
                : Text(
                    'Abstract text is not available.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'AUTHORS',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final author in paper.authors) _AuthorTile(author: author),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorTile extends StatelessWidget {
  const _AuthorTile({required this.author});

  final Author author;

  @override
  Widget build(BuildContext context) {
    final initials = author.name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: author.isParticipant
                ? AppColors.teal
                : AppColors.outline,
            child: Text(
              initials,
              style: TextStyle(
                color: author.isParticipant ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: AppColors.navy,
                  ),
                ),
                if (author.affiliation != null)
                  Text(
                    author.affiliation!,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    LabelChip(
                      label: author.role,
                      background: const Color(0xFFEFF2F6),
                      foreground: AppColors.navy,
                    ),
                    if (author.isParticipant)
                      const LabelChip(label: 'You', icon: Icons.person),
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
