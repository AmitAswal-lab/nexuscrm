import 'package:equatable/equatable.dart';

final class WorkspaceDocument extends Equatable {
  const WorkspaceDocument({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.description,
    required this.contentType,
    required this.sizeBytes,
    required this.isRetired,
    required this.uploadedByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? description;
  final String contentType;
  final int sizeBytes;
  final bool isRetired;
  final String uploadedByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isShareable => !isRetired;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    title,
    description,
    contentType,
    sizeBytes,
    isRetired,
    uploadedByUserId,
    updatedByUserId,
    createdAt,
    updatedAt,
  ];
}
