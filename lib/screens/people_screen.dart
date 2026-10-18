import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/roles.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Everyone registered, filterable by role. Organisers only (firestore.rules).
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Future<List<Person>>? _people;
  Role? _filter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _people ??= AppScope.of(context).repository.people();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: FutureBuilder<List<Person>>(
        future: _people,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load registrations.',
              onRetry: () => setState(
                () => _people = AppScope.of(context).repository.people(),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = [
            for (final p in snapshot.data!)
              if (_filter == null || p.role == _filter) p,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final role in Role.values)
                    ChoiceChip(
                      label: Text(role.label),
                      avatar: Icon(role.icon, size: 16, color: role.accent),
                      selected: _filter == role,
                      onSelected: (_) => setState(() => _filter = role),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < people.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: people[i].role.accent,
                          child: Text(
                            people[i].initials,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          people[i].fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        subtitle: Text(
                          '${people[i].role.label} · '
                          '${people[i].registrationId}',
                        ),
                      ),
                    ],
                    if (people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nobody in this group yet.'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
