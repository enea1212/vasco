import 'package:flutter/material.dart';

class StoryViewer extends StatefulWidget {
  final List<dynamic> photos;
  const StoryViewer({Key? key, required this.photos}) : super(key: key);

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Scaffold(
      appBar: AppBar(
        title: Text('Story Viewer'),
        actions: [
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${photos.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: photos.isEmpty
          ? const Center(child: Text('No photos to display.'))
          : PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final photo = photos[index];
                final imageUrl = photo['imageUrl'] ?? photo['url'] ?? '';
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: imageUrl.isNotEmpty
                        ? InteractiveViewer(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const CircularProgressIndicator();
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 80, color: Colors.white),
                            ),
                          )
                        : const Text('No image', style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
    );
  }
}
