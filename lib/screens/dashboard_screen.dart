import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/roles.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'conference_info_screen.dart';
import 'food_coupons_screen.dart';
import 'login_screen.dart';
import 'meal_desk_screen.dart';
import 'paper_screen.dart';
import 'participant_details_screen.dart';
import 'people_screen.dart';
import 'qr_pass_screen.dart';
import 'schedule_screen.dart';

/// Home screen for every role. Sections appear according to [Person.role].
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.person});

  final Person person;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Conference>? _conference;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _conference ??= AppScope.of(context).repository.conference();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your selfie will be removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final scope = AppScope.of(context);
    await scope.auth.signOut();
    await scope.selfies.delete(widget.person.email);
    scope.session.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 68,
        title: const Row(
          children: [
            ConeLogo(size: 48),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CONE'),
                  Text(
                    coneFullName,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('signOutButton'),
            tooltip: 'Sign out',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<Conference>(
        future: _conference,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Conference data could not be loaded.',
              onRetry: () => setState(
                () =>
                    _conference = AppScope.of(context).repository.conference(),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildBody(Conference conference) {
    final p = widget.person;
    final selfie = AppScope.of(context).session.selfie;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _ProfileCard(person: p, selfie: selfie),
        const SizedBox(height: 14),
        if (p.role.isStaff) ...[
          _MealDeskCard(onTap: () => _open(MealDeskScreen(email: p.email))),
          const SizedBox(height: 14),
        ],
        if (p.role == Role.organiser) ...[
          _OrganiserOverview(onPeople: () => _open(const PeopleScreen())),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                key: const Key('openQrPass'),
                icon: Icons.qr_code_2,
                label: 'QR pass',
                caption: '${p.role.label} pass',
                onTap: () =>
                    _open(QrPassScreen(conference: conference, person: p)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                key: const Key('openCoupons'),
                icon: Icons.restaurant_outlined,
                label: 'Food coupons',
                caption: '${p.coupons.length} meal coupons',
                onTap: () => _open(FoodCouponsScreen(person: p)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (p.paper != null) ...[
          _PaperCard(
            person: p,
            onTap: () => _open(PaperScreen(person: p)),
          ),
          const SizedBox(height: 14),
        ],
        if (p.talk != null) ...[
          _TalkCard(talk: p.talk!),
          const SizedBox(height: 14),
        ],
        if (p.host != null) ...[
          _HostCard(person: p),
          const SizedBox(height: 14),
        ],
        if (p.duties.isNotEmpty) ...[
          _DutiesCard(duties: p.duties),
          const SizedBox(height: 14),
        ],
        SectionCard(
          title: 'CONFERENCE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conference.name,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              const _IconLine(
                icon: Icons.event_outlined,
                text: 'Dates: to be announced',
              ),
              const _IconLine(
                icon: Icons.place_outlined,
                text: 'Venue: to be announced',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _MenuTile(
                key: const Key('openDetails'),
                icon: Icons.badge_outlined,
                title: 'My details',
                onTap: () => _open(ParticipantDetailsScreen(person: p)),
              ),
              if (p.paper != null) ...[
                const Divider(),
                _MenuTile(
                  key: const Key('openPaper'),
                  icon: Icons.article_outlined,
                  title: 'Paper & authors',
                  onTap: () => _open(PaperScreen(person: p)),
                ),
              ],
              const Divider(),
              _MenuTile(
                key: const Key('openSchedule'),
                icon: Icons.schedule_outlined,
                title: 'Schedule',
                onTap: () =>
                    _open(ScheduleScreen(conference: conference, person: p)),
              ),
              const Divider(),
              _MenuTile(
                key: const Key('openConference'),
                icon: Icons.info_outline,
                title: 'Conference information',
                onTap: () =>
                    _open(ConferenceInfoScreen(conference: conference)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Role badge in the role's accent colour.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.onDark = false});

  final Role role;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('roleBadge-${role.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: role.accent,
        borderRadius: BorderRadius.circular(20),
        border: onDark ? Border.all(color: Colors.white54) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            role.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.person, required this.selfie});

  final Person person;
  final Uint8List? selfie;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final chips = <String>[
      if (p.designation != null) p.designation!,
      if (p.category != null) 'Category ${p.category}',
      if (p.presentationLabel != null) p.presentationLabel!,
      if (p.disciplineShort != null) p.disciplineShort!,
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: p.role.accent, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.role.accent,
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.navyLight,
                  foregroundImage: selfie == null ? null : MemoryImage(selfie!),
                  child: Text(
                    p.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.registrationId,
                      key: const Key('dashboardRegistrationId'),
                      style: const TextStyle(
                        color: AppColors.tealBright,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RoleBadge(role: p.role, onDark: true),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in chips)
                  LabelChip(
                    label: c,
                    background: const Color(0x2E1DE3D4),
                    foreground: Colors.white,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: AppColors.amber,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.registrationStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealDeskCard extends StatelessWidget {
  const _MealDeskCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('openMealDesk'),
      clipBehavior: Clip.antiAlias,
      color: AppColors.navy,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: AppColors.tealBright,
                size: 40,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meal desk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Scan meal coupons and mark them served',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganiserOverview extends StatefulWidget {
  const _OrganiserOverview({required this.onPeople});

  final VoidCallback onPeople;

  @override
  State<_OrganiserOverview> createState() => _OrganiserOverviewState();
}

class _OrganiserOverviewState extends State<_OrganiserOverview> {
  Future<(Map<Role, int>, int)>? _stats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stats ??= _load();
  }

  Future<(Map<Role, int>, int)> _load() async {
    final repo = AppScope.of(context).repository;
    final results = await Future.wait([repo.roleCounts(), repo.mealsServed()]);
    return (results[0] as Map<Role, int>, results[1] as int);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'OVERVIEW',
      child: FutureBuilder<(Map<Role, int>, int)>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Row(
              children: [
                const Expanded(child: Text('Could not load the overview.')),
                TextButton(
                  onPressed: () => setState(() => _stats = _load()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final (counts, meals) = snapshot.data!;
          final total = counts.values.fold<int>(0, (a, b) => a + b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Stat(value: '$total', label: 'Registered'),
                  _Stat(
                    key: const Key('mealsServed'),
                    value: '$meals',
                    label: 'Meals served',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in Role.values)
                    LabelChip(
                      label: '${role.label} ${counts[role] ?? 0}',
                      icon: role.icon,
                      background: role.background,
                      foreground: role.accent,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('openPeople'),
                onPressed: widget.onPeople,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('People'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label});

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
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.teal, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.navy,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.person, required this.onTap});

  final Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeading('YOUR ABSTRACT', chevron: true),
              const SizedBox(height: 8),
              Text(
                p.paper!.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (p.presentationLabel != null)
                    LabelChip(
                      label: p.presentationLabel!,
                      icon: p.presentationType == 'O'
                          ? Icons.record_voice_over_outlined
                          : Icons.dashboard_outlined,
                    ),
                  if (p.category != null)
                    LabelChip(label: 'Category ${p.category}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkCard extends StatelessWidget {
  const _TalkCard({required this.talk});

  final Talk talk;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      key: const Key('talkCard'),
      title: 'YOUR TALK',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            talk.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _IconLine(icon: Icons.mic_none, text: talk.session),
          _IconLine(
            icon: Icons.schedule,
            text: '${talk.day} · ${talk.start}–${talk.end}',
          ),
          _IconLine(icon: Icons.place_outlined, text: talk.venue),
          if (talk.abstract != null) ...[
            const SizedBox(height: 8),
            Text(
              talk.abstract!,
              style: const TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final host = person.host!;
    return SectionCard(
      key: const Key('hostCard'),
      title: 'YOUR HOST',
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.navy,
            child: Icon(Icons.support_agent, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  host.role,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (host.mobile != null)
                  Text(
                    host.mobile!,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DutiesCard extends StatelessWidget {
  const _DutiesCard({required this.duties});

  final List<String> duties;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      key: const Key('dutiesCard'),
      title: 'YOUR DUTIES',
      child: Column(
        children: [
          for (final d in duties)
            _IconLine(icon: Icons.check_circle_outline, text: d),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading(this.text, {this.chevron = false});

  final String text;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (chevron)
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.teal),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
