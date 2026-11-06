import 'package:flutter/material.dart';

import 'mail.dart';
import 'store.dart';
import 'theme.dart';

class WeatherToday extends StatefulWidget {
  const WeatherToday({super.key});

  @override
  State<WeatherToday> createState() => _WeatherTodayState();
}

class _WeatherTodayState extends State<WeatherToday> {
  _Forecast? _forecast;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ({Map<String, Object?>? data, String? error}) result =
        await OutboundMail.weather();
    if (!mounted) {
      return;
    }
    final Map<String, Object?>? data = result.data;
    if (result.error != null || data == null) {
      setState(() {
        _loading = false;
        _error = result.error ?? 'Weather is unavailable right now.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _error = null;
      _forecast = _Forecast(
        place: (data['place'] ?? '').toString(),
        country: (data['country'] ?? '').toString(),
        condition: (data['condition'] ?? '').toString(),
        icon: (data['icon'] ?? '').toString(),
        tempC: _round(data['tempC']),
        highC: _round(data['highC']),
        lowC: _round(data['lowC']),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: kPaper,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _loading ? null : _load,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kLine),
            ),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SizedBox(
        width: 148,
        height: 42,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: kInk),
          ),
        ),
      );
    }
    final _Forecast? forecast = _forecast;
    if (forecast == null) {
      return Text(
        _error ?? 'Weather is unavailable right now.',
        style: const TextStyle(
          color: kMute,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final String where = forecast.place.isEmpty
        ? forecast.country
        : '${forecast.place}${forecast.country.isEmpty ? '' : ', ${forecast.country}'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (forecast.icon.isNotEmpty)
          Image.network(
            forecast.icon,
            width: 42,
            height: 42,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.wb_cloudy_outlined, color: kInk),
          )
        else
          const Icon(Icons.wb_cloudy_outlined, color: kInk),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${forecast.tempC}°',
                style: const TextStyle(
                  color: kInk,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Today · ${forecast.condition} · ${forecast.highC}° / ${forecast.lowC}°',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kMute,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Forecast {
  const _Forecast({
    required this.place,
    required this.country,
    required this.condition,
    required this.icon,
    required this.tempC,
    required this.highC,
    required this.lowC,
  });

  final String place;
  final String country;
  final String condition;
  final String icon;
  final int tempC;
  final int highC;
  final int lowC;
}

int _round(Object? value) {
  if (value is num) {
    return value.round();
  }
  return 0;
}

class AssistantMark extends StatelessWidget {
  const AssistantMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double badge = size * 0.46;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipOval(
            child: Image.asset(
              'assets/brand/driftline_logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            right: -badge * 0.18,
            bottom: -badge * 0.12,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
                border: Border.all(color: kPaper, width: 1.4),
              ),
              child: Icon(
                Icons.headset_mic,
                size: badge * 0.62,
                color: kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideHandle extends StatelessWidget {
  const GuideHandle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kOrange,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        child: const SizedBox(
          width: 48,
          height: 58,
          child: Center(child: AssistantMark(size: 32)),
        ),
      ),
    );
  }
}

class TripGuide extends StatefulWidget {
  const TripGuide({super.key, required this.user});

  final AppUser user;

  @override
  State<TripGuide> createState() => _TripGuideState();
}

class _TripGuideState extends State<TripGuide> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Line> _lines = <_Line>[];
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<({String role, String text})> saved =
        await UserStore.instance.guideMessages(widget.user.id);
    if (!mounted) {
      return;
    }
    if (saved.isEmpty) {
      const String opening = 'Which country do you want to visit?';
      await UserStore.instance.addGuideMessage(
        userId: widget.user.id,
        role: 'assistant',
        text: opening,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(const _Line(role: 'assistant', text: opening));
        _ready = true;
      });
      return;
    }
    setState(() {
      _lines.addAll(
        saved.map(
          (({String role, String text}) line) =>
              _Line(role: line.role, text: line.text),
        ),
      );
      _ready = true;
    });
    _jump();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _text.text.trim();
    if (text.isEmpty || _busy || !_ready) {
      return;
    }
    setState(() {
      _lines.add(_Line(role: 'user', text: text));
      _busy = true;
      _text.clear();
    });
    await UserStore.instance.addGuideMessage(
      userId: widget.user.id,
      role: 'user',
      text: text,
    );
    _jump();
    final ({String? reply, String? error}) result = await OutboundMail.guide(
      preferences: widget.user.preferencesVoyage,
      home: widget.user.pays,
      language: widget.user.langue,
      messages: <Map<String, String>>[
        for (final _Line line in _lines)
          <String, String>{'role': line.role, 'text': line.text},
      ],
    );
    final String answer =
        result.reply ?? result.error ?? 'The travel guide is unavailable.';
    await UserStore.instance.addGuideMessage(
      userId: widget.user.id,
      role: 'assistant',
      text: answer,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _lines.add(_Line(role: 'assistant', text: answer));
    });
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final String taste = widget.user.preferences.isEmpty
        ? 'No travel preferences yet'
        : widget.user.preferences.join(' · ');
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kInk,
        elevation: 0,
        title: const Row(
          children: <Widget>[
            AssistantMark(size: 26),
            SizedBox(width: 10),
            Text(
              'Assistant',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                taste,
                style: const TextStyle(
                  color: kMute,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount: _lines.length + (_busy ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index >= _lines.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: kInk,
                        ),
                      ),
                    ),
                  );
                }
                final _Line line = _lines[index];
                final bool mine = line.role == 'user';
                final Widget bubble = Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? kInk : kNavy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      fontFamily: kFont,
                      fontVariations: kReading,
                      color: kPaper,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                );
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: mine
                      ? bubble
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(right: 8, bottom: 10),
                              child: AssistantMark(),
                            ),
                            Flexible(child: bubble),
                          ],
                        ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Name a country',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: kInk,
                      foregroundColor: kPaper,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line {
  const _Line({required this.role, required this.text});

  final String role;
  final String text;
}
