import 'package:flutter/material.dart';

import '../../theme.dart';

const List<String> kTripTypes = <String>[
  'Aventure',
  'Détente',
  'Famille',
  'Culturel',
];

const List<String> kTripStatuses = <String>[
  'Planned',
  'Active',
  'Done',
  'Cancelled',
];

String tripStatusLabel(String status) {
  switch (status) {
    case 'Planned':
      return 'Planifié';
    case 'Active':
      return 'En cours';
    case 'Done':
      return 'Terminé';
    case 'Cancelled':
      return 'Annulé';
    default:
      return status;
  }
}

class TripScaffold extends StatelessWidget {
  const TripScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title),
      ),
      body: body,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: bottom!,
            ),
    );
  }
}

class TripPanel extends StatelessWidget {
  const TripPanel({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: color ?? kPaper,
        borderRadius: kCardRadius,
        border: Border.all(color: const Color(0xB3B2A4A1)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TripFieldShell extends StatelessWidget {
  const TripFieldShell({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: kPaper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: kMute,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class TripPrimaryButton extends StatelessWidget {
  const TripPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: kInk,
        foregroundColor: kPaper,
        disabledBackgroundColor: kNavy,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class TripStatusChip extends StatelessWidget {
  const TripStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool active = status == 'Active';
    final Color background = switch (status) {
      'Active' => kGreen,
      'Done' => kLilac,
      'Cancelled' => kNavy,
      _ => kGold,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tripStatusLabel(status),
        style: TextStyle(
          color: active ? kPaper : kInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<bool> confirmTripAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
