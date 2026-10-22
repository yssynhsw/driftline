import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import 'trip_chrome.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: kCardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: kCardRadius,
              border: Border.all(color: kLine),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          trip.titre,
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TripStatusChip(status: trip.statut),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${trip.destination} · ${trip.pays}',
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${displayCalendarDate(trip.dateDepart)} – ${displayCalendarDate(trip.dateRetour)}',
                    style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Budget ${formatBudget(trip.budget)} · ${trip.nombreVoyageurs} voyageur${trip.nombreVoyageurs > 1 ? 's' : ''}',
                    style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
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
