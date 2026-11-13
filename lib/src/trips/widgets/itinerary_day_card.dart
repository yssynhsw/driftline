import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../itinerary_day.dart';

class ItineraryDayCard extends StatelessWidget {
  const ItineraryDayCard({super.key, required this.day, required this.onTap});

  final ItineraryDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: kCardRadius,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: kMintGradient,
              borderRadius: kCardRadius,
              border: Border.all(color: const Color(0xB3FFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Jour ${day.dayNumber}',
                    style: const TextStyle(
                      color: kMute,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.title,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayCalendarDate(day.date),
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w600),
                  ),
                  if (day.startTime.trim().isNotEmpty ||
                      day.endTime.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '${day.startTime.isEmpty ? '—' : day.startTime} → ${day.endTime.isEmpty ? '—' : day.endTime}',
                      style: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (day.description.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      day.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMute, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Budget estimé ${formatBudget(day.estimatedBudget)}',
                    style: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
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
