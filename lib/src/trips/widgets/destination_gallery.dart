import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../gallery_photo.dart';
import '../wikimedia_images.dart';
import 'trip_chrome.dart';

/// Country photo gallery section for trip details (5 emblematic photos).
class DestinationGallerySection extends StatelessWidget {
  const DestinationGallerySection({
    super.key,
    required this.destination,
    this.country = '',
    required this.photos,
    this.loading = false,
  });

  final String destination;
  final String country;
  final List<GalleryPhoto> photos;
  final bool loading;

  String get _galleryLabel {
    final String pays = country.trim();
    if (pays.isNotEmpty) {
      return '5 photos · $pays';
    }
    final String dest = destination.trim();
    return dest.isEmpty ? 'Galerie photos' : 'Galerie photos · $dest';
  }

  @override
  Widget build(BuildContext context) {
    return TripPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Découvrir la destination',
            style: TextStyle(
              color: kInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _galleryLabel,
            style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: kInk,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Recherche de 5 photos du pays…',
                      style: TextStyle(
                        color: kMute,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (photos.isEmpty)
            const Text(
              'Aucune photo fiable disponible pour ce pays pour le moment.',
              style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (BuildContext context, int index) {
                final GalleryPhoto photo = photos[index];
                return _GalleryTile(
                  photo: photo,
                  onTap: () => _openFullscreen(context, index),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, int index) {
    final String label =
        country.trim().isNotEmpty ? country.trim() : destination;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DestinationGalleryViewer(
          photos: photos,
          initialIndex: index,
          destination: label,
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.photo, required this.onTap});

  final GalleryPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8EEF2),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: WikimediaImages.normalizeForDisplay(photo.url),
              httpHeaders: WikimediaImages.httpHeaders,
              cacheManager: WikimediaImages.cacheManager,
              fit: BoxFit.cover,
              memCacheWidth: 960,
              placeholder: (BuildContext context, String _) => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kInk),
                ),
              ),
              errorWidget: (BuildContext context, String url, Object error) =>
                  const Center(
                child: Icon(Icons.broken_image_outlined, color: kMute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DestinationGalleryViewer extends StatefulWidget {
  const DestinationGalleryViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.destination,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;
  final String destination;

  @override
  State<DestinationGalleryViewer> createState() =>
      _DestinationGalleryViewerState();
}

class _DestinationGalleryViewerState extends State<DestinationGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GalleryPhoto current = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: kPaper,
        title: Text(
          '${widget.destination} · ${_index + 1}/${widget.photos.length}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (int value) => setState(() => _index = value),
              itemBuilder: (BuildContext context, int index) {
                final GalleryPhoto photo = widget.photos[index];
                return InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: WikimediaImages.normalizeForDisplay(photo.url),
                    httpHeaders: WikimediaImages.httpHeaders,
                    cacheManager: WikimediaImages.cacheManager,
                    fit: BoxFit.contain,
                    memCacheWidth: 1280,
                    placeholder: (BuildContext context, String _) =>
                        const Center(
                      child: CircularProgressIndicator(color: kPaper),
                    ),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            const Icon(
                      Icons.broken_image_outlined,
                      color: kPaper,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          ),
          if (current.credit.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                current.credit,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kPaper, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
