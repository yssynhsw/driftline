import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../trip_services.dart';

class WeatherPanel extends StatefulWidget {
  const WeatherPanel({
    super.key,
    required this.trip,
    this.forecast,
    this.autoload = true,
  });

  final Trip trip;
  final DestinationForecast? forecast;
  final bool autoload;

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  late final OpenMeteoForecastService _service = () {
    final DestinationForecast forecast =
        widget.forecast ?? TripServiceLocator.destinationForecast();
    if (forecast is OpenMeteoForecastService) {
      return forecast;
    }
    return OpenMeteoForecastService();
  }();

  WeatherForecastResult? _result;
  bool _loading = false;
  String? _error;
  bool _useMyLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final WeatherForecastResult result;
      if (_useMyLocation) {
        final Position position = await _requirePosition();
        result = await _service.loadAt(
          latitude: position.latitude,
          longitude: position.longitude,
          label: 'Ma position',
          dateDepart: storeCalendarDate(DateTime.now()),
          dateRetour: storeCalendarDate(
            DateTime.now().add(const Duration(days: 6)),
          ),
        );
      } else {
        final String destinationQuery = widget.trip.pays.trim().isEmpty
            ? widget.trip.destination.trim()
            : '${widget.trip.destination.trim()}, ${widget.trip.pays.trim()}';
        result = await _service.load(
          destination: destinationQuery,
          dateDepart: widget.trip.dateDepart,
          dateRetour: widget.trip.dateRetour,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<Position> _requirePosition() async {
    final bool service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      throw const OpenMeteoException(
        'Active la localisation pour afficher la météo autour de toi.',
      );
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const OpenMeteoException(
        'Autorisation de localisation refusée.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WeatherForecastResult? result = _result;
    final WeatherCurrent? current = result?.current;
    final int code = current?.weatherCode ??
        (result?.days.isNotEmpty == true ? result!.days.first.weatherCode : 1);
    final List<Color> gradient = _gradientFor(code);

    return ClipRRect(
      borderRadius: kCardRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Météo',
                      style: TextStyle(
                        color: kPaper,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _useMyLocation
                        ? 'Météo de la destination'
                        : 'Autour de moi',
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _useMyLocation = !_useMyLocation);
                            _load();
                          },
                    icon: Icon(
                      _useMyLocation
                          ? Icons.place_rounded
                          : Icons.my_location_rounded,
                      color: kPaper,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, color: kPaper),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(color: kPaper),
                  ),
                )
              else if (_error != null)
                _ErrorBlock(message: _error!, onRetry: _load)
              else if (result == null ||
                  (result.days.isEmpty && result.current == null))
                const Text(
                  'Prévisions encore indisponibles pour ces dates.',
                  style: TextStyle(
                    color: kPaper,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...<Widget>[
                Text(
                  result.destination,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _useMyLocation
                      ? 'Autour de toi · actualisé'
                      : 'Destination du voyage',
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            current == null
                                ? '${result.days.first.tempMax.toStringAsFixed(0)}°'
                                : '${current.temperature.toStringAsFixed(0)}°',
                            style: const TextStyle(
                              color: kPaper,
                              fontSize: 64,
                              height: 0.95,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                            ),
                          ),
                          Text(
                            current?.conditionLabel ??
                                result.days.first.conditionLabel,
                            style: const TextStyle(
                              color: kPaper,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (current != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              'Ressenti ${current.feelsLike.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _materialIcon(code),
                      color: kPaper,
                      size: 64,
                    ),
                  ],
                ),
                if (current != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      _Metric(
                        label: 'Humidité',
                        value: '${current.humidity}%',
                      ),
                      _Metric(
                        label: 'Vent',
                        value: '${current.windSpeed.toStringAsFixed(0)} km/h',
                      ),
                      if (result.days.isNotEmpty)
                        _Metric(
                          label: 'Pluie',
                          value:
                              '${result.days.first.precipitationProbability ?? 0}%',
                        ),
                    ],
                  ),
                ],
                if (result.hourly.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  const Text(
                    'Prochaines heures',
                    style: TextStyle(
                      color: kPaper,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: result.hourly.length.clamp(0, 12),
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final WeatherHourlyForecast hour = result.hourly[index];
                        return _HourChip(hour: hour);
                      },
                    ),
                  ),
                ],
                if (result.days.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  const Text(
                    '7 jours',
                    style: TextStyle(
                      color: kPaper,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final WeatherDayForecast day in result.days.take(7))
                    _DayRow(day: day),
                ],
                if (result.limitedHorizon) ...<Widget>[
                  const SizedBox(height: 10),
                  const Text(
                    'Certaines dates du voyage dépassent l’horizon Open-Meteo '
                    '(~16 jours) : ce ne sont pas des prévisions garanties.',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                ],
                if (result.days.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    result.days.first.recommendation,
                    style: const TextStyle(
                      color: kPaper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _gradientFor(int code) {
    if (code == 0) {
      return const <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE), Color(0xFF1F9D62)];
    }
    if (code <= 3) {
      return const <Color>[Color(0xFF667EEA), Color(0xFF64B5F6), Color(0xFF26A69A)];
    }
    if (code <= 48) {
      return const <Color>[Color(0xFF757F9A), Color(0xFFD7DDE8)];
    }
    if (code <= 67 || (code >= 80 && code <= 82) || code >= 95) {
      return const <Color>[Color(0xFF2C3E50), Color(0xFF4CA1AF)];
    }
    if (code <= 77) {
      return const <Color>[Color(0xFF83A4D4), Color(0xFFB6FBFF)];
    }
    return const <Color>[Color(0xFF323236), Color(0xFF17171A)];
  }

  IconData _materialIcon(int code) {
    switch (weatherIcon(code)) {
      case IconDataWeather.clear:
        return Icons.wb_sunny_rounded;
      case IconDataWeather.partlyCloudy:
        return Icons.wb_cloudy_rounded;
      case IconDataWeather.cloudy:
        return Icons.cloud_rounded;
      case IconDataWeather.fog:
        return Icons.blur_on_rounded;
      case IconDataWeather.rain:
        return Icons.umbrella_rounded;
      case IconDataWeather.snow:
        return Icons.ac_unit_rounded;
      case IconDataWeather.thunder:
        return Icons.thunderstorm_rounded;
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: kPaper,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({required this.hour});

  final WeatherHourlyForecast hour;

  @override
  Widget build(BuildContext context) {
    final String label =
        '${hour.time.hour.toString().padLeft(2, '0')}h';
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label, style: const TextStyle(color: kPaper, fontSize: 12)),
          const SizedBox(height: 6),
          Icon(
            hour.weatherCode <= 1
                ? Icons.wb_sunny_rounded
                : hour.weatherCode <= 67
                    ? Icons.umbrella_rounded
                    : Icons.cloud_rounded,
            color: kPaper,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            '${hour.temperature.toStringAsFixed(0)}°',
            style: const TextStyle(
              color: kPaper,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final WeatherDayForecast day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x28FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 78,
              child: Text(
                displayCalendarDate(day.date),
                style: const TextStyle(
                  color: kPaper,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              day.weatherCode <= 1
                  ? Icons.wb_sunny_rounded
                  : day.weatherCode >= 95
                      ? Icons.thunderstorm_rounded
                      : Icons.cloud_rounded,
              color: kPaper,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                day.conditionLabel,
                style: const TextStyle(color: Color(0xE6FFFFFF)),
              ),
            ),
            Text(
              '${day.tempMin.toStringAsFixed(0)}° / ${day.tempMax.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: kPaper,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          message,
          style: const TextStyle(
            color: kPaper,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: kPaper),
          child: const Text('Réessayer'),
        ),
      ],
    );
  }
}
