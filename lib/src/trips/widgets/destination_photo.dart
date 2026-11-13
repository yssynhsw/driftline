import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../destination_cover.dart';
import '../destination_cover_service.dart';
import '../wikimedia_images.dart';

/// Immersive destination photograph with disk cache, loading and fallback.
class DestinationPhoto extends StatefulWidget {
  const DestinationPhoto({
    super.key,
    required this.destination,
    this.country = '',
    this.imageUrl,
    this.credit,
    this.matchLevel,
    this.height = 180,
    this.borderRadius,
    this.overlayLabel,
    this.heroTag,
    this.autoload = true,
    this.onResolved,
  });

  final String destination;
  final String country;
  final String? imageUrl;
  final String? credit;
  final String? matchLevel;
  final double height;
  final BorderRadius? borderRadius;
  final String? overlayLabel;
  final Object? heroTag;
  final bool autoload;
  final ValueChanged<DestinationCoverResult>? onResolved;

  @override
  State<DestinationPhoto> createState() => _DestinationPhotoState();
}

class _DestinationPhotoState extends State<DestinationPhoto> {
  final DestinationCoverService _service = DestinationCoverService();
  bool _loading = false;
  String? _url;
  String? _credit;
  String? _matchLevel;
  bool _representative = false;
  List<String> _candidates = <String>[];
  int _candidateIndex = 0;

  @override
  void initState() {
    super.initState();
    _applyIncomingUrl(widget.imageUrl);
    _credit = widget.credit;
    _matchLevel = widget.matchLevel;
    if ((_url == null || _url!.isEmpty) && widget.autoload) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(covariant DestinationPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool destinationChanged =
        oldWidget.destination != widget.destination ||
        oldWidget.country != widget.country;
    final String? incoming = widget.imageUrl?.trim().isEmpty ?? true
        ? null
        : widget.imageUrl;
    if (incoming != null && incoming != _url) {
      setState(() {
        _applyIncomingUrl(incoming);
        _credit = widget.credit;
        _matchLevel = widget.matchLevel;
        _representative = false;
      });
      return;
    }
    if (destinationChanged && widget.autoload) {
      _resolve();
    }
  }

  void _applyIncomingUrl(String? raw) {
    final String? trimmed = raw?.trim().isEmpty ?? true ? null : raw!.trim();
    if (trimmed == null) {
      _url = null;
      _candidates = <String>[];
      _candidateIndex = 0;
      return;
    }
    _candidates = WikimediaImages.displayCandidates(trimmed);
    _candidateIndex = 0;
    _url = _candidates.isEmpty ? trimmed : _candidates.first;
  }

  void _tryNextCandidate() {
    if (_candidateIndex + 1 >= _candidates.length) {
      return;
    }
    setState(() {
      _candidateIndex += 1;
      _url = _candidates[_candidateIndex];
    });
  }

  Future<void> _resolve() async {
    if (!mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final DestinationCoverResult result = await _service.resolve(
        destination: widget.destination,
        country: widget.country,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyIncomingUrl(
          result.imageUrl.trim().isEmpty ? null : result.imageUrl,
        );
        _credit = result.credit;
        _matchLevel = result.matchLevel;
        _representative = result.representativeOnly ||
            result.matchLevel == DestinationCoverResult.levelFallback;
        _loading = false;
      });
      widget.onResolved?.call(result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _url = null;
        _candidates = <String>[];
        _candidateIndex = 0;
        _credit = '';
        _matchLevel = DestinationCoverResult.levelFallback;
        _representative = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = widget.borderRadius ?? kCardRadius;
    final String? url = (_url == null || _url!.isEmpty) ? null : _url;

    Widget image = _loading
        ? _Loading(height: widget.height)
        : (url == null)
            ? _Fallback(
                height: widget.height,
                destination: widget.destination,
              )
            : CachedNetworkImage(
                key: ValueKey<String>('cover-$url'),
                imageUrl: url,
                httpHeaders: WikimediaImages.httpHeaders,
                cacheManager: WikimediaImages.cacheManager,
                height: widget.height,
                width: double.infinity,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 280),
                fadeOutDuration: const Duration(milliseconds: 120),
                placeholder: (BuildContext context, String _) =>
                    _Loading(height: widget.height),
                errorWidget: (BuildContext context, String failed, Object error) {
                  // Automatically try the next Wikimedia thumb size / original.
                  if (_candidateIndex + 1 < _candidates.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _tryNextCandidate();
                      }
                    });
                    return _Loading(height: widget.height);
                  }
                  return _Fallback(
                    height: widget.height,
                    destination: widget.destination,
                  );
                },
                memCacheWidth: 1280,
              );

    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    final String? badge = _matchLevel == null
        ? null
        : (_representative
            ? 'Photo représentative'
            : (_matchLevel == DestinationCoverResult.levelExact
                ? null
                : 'Photo à proximité'));

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00000000),
                    Color(0x66000000),
                  ],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xCC121212),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: kPaper,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: kFont,
                    ),
                  ),
                ),
              ),
            if (widget.overlayLabel != null &&
                widget.overlayLabel!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: (_credit != null && _credit!.trim().isNotEmpty)
                    ? 34
                    : 14,
                child: Text(
                  widget.overlayLabel!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kPaper,
                    fontFamily: kFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    shadows: <Shadow>[
                      Shadow(color: Color(0x66000000), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            if (_credit != null && _credit!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child: Text(
                  _credit!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: kFont,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: const Color(0xFFE8EEF2),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: kInk),
          ),
          SizedBox(height: 10),
          Text(
            'Chargement de la photo…',
            style: TextStyle(
              color: kInk,
              fontWeight: FontWeight.w600,
              fontFamily: kFont,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.height, required this.destination});

  final double height;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: kMintGradient),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.landscape_rounded, size: 42, color: kInk),
          const SizedBox(height: 8),
          Text(
            destination.trim().isEmpty ? 'Destination' : destination,
            style: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w700,
              fontFamily: kFont,
            ),
          ),
        ],
      ),
    );
  }
}
