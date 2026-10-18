import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/roles.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';

/// The QR payload for a participant's pass: the pass ID and nothing else.
/// No email, mobile number, codes or tokens are ever encoded.
String passQrPayload(Person person) => person.passId;

class QrPassScreen extends StatelessWidget {
  const QrPassScreen({
    super.key,
    required this.conference,
    required this.person,
  });

  final Conference conference;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Scaffold(
      appBar: AppBar(title: const Text('QR pass')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: AppColors.navy,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          const ConeLogo(size: 56),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CONFERENCE PASS',
                                  style: TextStyle(
                                    color: AppColors.tealBright,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  conference.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        children: [
                          Text(
                            p.fullName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              RoleBadge(role: p.role),
                              if (p.designation != null)
                                LabelChip(label: p.designation!),
                              if (p.category != null)
                                LabelChip(label: 'Category ${p.category}'),
                              if (p.presentationLabel != null)
                                LabelChip(label: p.presentationLabel!),
                              if (p.disciplineShort != null)
                                LabelChip(label: p.disciplineShort!),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PassQr(payload: passQrPayload(p)),
                          const SizedBox(height: 10),
                          Text(
                            p.passId,
                            key: const Key('passId'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            'Registration ${p.registrationId}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: const Key('passRoleBand'),
                      width: double.infinity,
                      color: p.role.accent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Text(
                        '${p.role.label.toUpperCase()} · CONE · $coneFullName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

/// Renders [payload] as a QR code.
class PassQr extends StatelessWidget {
  const PassQr({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload,
      size: 220,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      semanticsLabel: 'QR code for pass $payload',
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.navy,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.navy,
      ),
    );
  }
}
