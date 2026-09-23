import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PlacementPdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;

  const PlacementPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  State<PlacementPdfViewerScreen> createState() => _PlacementPdfViewerScreenState();
}

class _PlacementPdfViewerScreenState extends State<PlacementPdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  bool _isFullScreen = false;

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.pdfUrl.trim();
    
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded), 
          onPressed: () => Navigator.pop(context)
        ),
        title: Text(
          widget.title, 
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 18)
        ),
        centerTitle: true,
      ),
      body: url.isEmpty 
        ? const Center(child: Text('Document link is missing'))
        : Stack(
            children: [
              SfPdfViewer.network(
                url,
                controller: _pdfViewerController,
                onDocumentLoaded: (details) {
                  setState(() => _isLoading = false);
                },
                onDocumentLoadFailed: (details) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load PDF: ${details.description}')),
                  );
                },
                enableDoubleTapZooming: true,
              ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  heroTag: 'placement_fullscreen_toggle',
                  onPressed: _toggleFullScreen,
                  child: Icon(_isFullScreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded),
                ),
              ),
              if (_isFullScreen)
                Positioned(
                  left: 16,
                  top: 16,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _toggleFullScreen,
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}
