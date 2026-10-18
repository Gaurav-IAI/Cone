import 'package:flutter/material.dart';

import '../app/roles.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Read-only registration details. Only fields present for the role appear.
class ParticipantDetailsScreen extends StatelessWidget {
  const ParticipantDetailsScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final p = person;
    String yesNo(bool v, String yes, String no) => v ? yes : no;

    return Scaffold(
      appBar: AppBar(title: const Text('My details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: 'PERSONAL',
            child: Column(
              children: [
                InfoRow(label: 'Name', value: p.fullName),
                InfoRow(label: 'Email', value: p.email),
                InfoRow(label: 'Mobile', value: p.maskedMobile),
                InfoRow(label: 'Affiliation', value: p.affiliation),
                if (p.designation != null)
                  InfoRow(label: 'Designation', value: p.designation!),
                if (p.workingAs != null)
                  InfoRow(label: 'Working as', value: p.workingAs!),
                if (p.district != null)
                  InfoRow(label: 'District code', value: p.district!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'REGISTRATION',
            child: Column(
              children: [
                InfoRow(label: 'Registration ID', value: p.registrationId),
                InfoRow(label: 'Role', value: p.role.label),
                InfoRow(label: 'Status', value: p.registrationStatus),
                if (p.discipline != null)
                  InfoRow(label: 'Discipline', value: p.discipline!),
                if (p.category != null)
                  InfoRow(label: 'Category', value: p.category!),
                if (p.presentationLabel != null)
                  InfoRow(label: 'Presentation', value: p.presentationLabel!),
                if (p.registrationFee != null)
                  InfoRow(
                    label: 'Registration fee',
                    value: '₹${p.registrationFee}',
                  ),
                if (p.feesReceived != null)
                  InfoRow(label: 'Payment reference', value: p.feesReceived!),
                if (p.softCopy != null)
                  InfoRow(
                    label: 'Soft copy',
                    value: yesNo(p.softCopy!, 'Submitted', 'Not submitted'),
                  ),
                if (p.accommodation != null)
                  InfoRow(
                    label: 'Accommodation',
                    value: yesNo(
                      p.accommodation!,
                      'Requested',
                      'Not requested',
                    ),
                  ),
                if (p.earlierAwardee != null)
                  InfoRow(
                    label: 'Earlier awardee',
                    value: yesNo(p.earlierAwardee!, 'Yes', 'No'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
