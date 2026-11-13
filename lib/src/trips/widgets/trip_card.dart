import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import 'destination_photo.dart';
import 'trip_chrome.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: kPaper,
        borderRadius: kCardRadius,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: kCardRadius,
              border: Border.all(color: kLine),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DestinationPhoto(
                  destination: trip.destination,
                  country: trip.pays,
                  imageUrl: trip.coverPhotoUrl,
                  credit: trip.coverPhotoCredit,
                  matchLevel: trip.coverMatchLevel,
                  height: 168,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  overlayLabel: trip.destination,
                  heroTag: 'trip-photo-${trip.id}',
                  autoload: trip.coverPhotoUrl.trim().isEmpty,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
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
                      const SizedBox(height: 6),
                      Text(
                        '${trip.destination} · ${trip.pays}',
                        style: const TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${displayCalendarDate(trip.dateDepart)} – ${displayCalendarDate(trip.dateRetour)}',
                        style: const TextStyle(
                          color: kMute,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Budget ${formatBudget(trip.budget)} · ${trip.nombreVoyageurs} voyageur${trip.nombreVoyageurs > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: kMute,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
