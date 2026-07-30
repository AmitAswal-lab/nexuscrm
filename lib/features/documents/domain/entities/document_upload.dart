import 'dart:typed_data';

import 'package:equatable/equatable.dart';

final class DocumentUpload extends Equatable {
  const DocumentUpload({
    required this.title,
    required this.description,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  static const maxSizeBytes = 10 * 1024 * 1024;

  final String title;
  final String? description;
  final String fileName;
  final String contentType;
  final Uint8List bytes;

  @override
  List<Object?> get props => [
    title,
    description,
    fileName,
    contentType,
    bytes.length,
  ];
}
