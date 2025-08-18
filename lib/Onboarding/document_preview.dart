import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;

class PreviewScreen extends StatefulWidget {
  final File? file;
  final String? url;

  const PreviewScreen({super.key, this.file, this.url});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  PdfController? _pdfController;
  Future<Uint8List>? _pdfBytesFuture;

  bool get isPdf {
    final path = widget.file?.path ?? widget.url ?? '';
    return path.toLowerCase().endsWith('.pdf');
  }

  @override
  void initState() {
    super.initState();
    if (widget.file != null && isPdf) {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.file!.path),
      );
    } else if (widget.url != null && isPdf) {
      _pdfBytesFuture = _fetchPdfBytesFromUrl(widget.url!);
    }
  }

  Future<Uint8List> _fetchPdfBytesFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load PDF');
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file == null && widget.url == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(child: Text('No file or URL provided')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Preview Document')),
      body: isPdf ? _buildPdfView() : _buildImageView(),
    );
  }

  Widget _buildImageView() {
    final ImageProvider provider =
        widget.file != null
            ? FileImage(widget.file!)
            : NetworkImage(widget.url!) as ImageProvider;

    return Center(child: Image(image: provider));
  }

  Widget _buildPdfView() {
    if (_pdfController != null) {
      // Local PDF file
      return PdfView(controller: _pdfController!);
    } else if (_pdfBytesFuture != null) {
      // PDF from URL
      return FutureBuilder<Uint8List>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final controller = PdfController(
              document: PdfDocument.openData(snapshot.data!),
            );
            return PdfView(controller: controller);
          }
        },
      );
    } else {
      return const Center(child: Text('Invalid PDF source'));
    }
  }
}
