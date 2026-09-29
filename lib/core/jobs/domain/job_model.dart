import 'job_status.dart';
import 'job_type.dart';

/// Represents a persistent background/foreground job record.
class JobModel {
  final String id;
  final JobType jobType;
  final String moduleType;
  final JobStatus status;
  final double progress; // 0.0 to 1.0
  final String? inputJson;
  final String? outputJson;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const JobModel({
    required this.id,
    required this.jobType,
    required this.moduleType,
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.inputJson,
    this.outputJson,
    this.errorMessage,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  JobModel copyWith({
    String? id,
    JobType? jobType,
    String? moduleType,
    JobStatus? status,
    double? progress,
    String? inputJson,
    String? outputJson,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      jobType: jobType ?? this.jobType,
      moduleType: moduleType ?? this.moduleType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      inputJson: inputJson ?? this.inputJson,
      outputJson: outputJson ?? this.outputJson,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_type': jobType.value,
      'module_type': moduleType,
      'status': status.value,
      'progress': progress,
      'input_json': inputJson,
      'output_json': outputJson,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
    };
  }

  factory JobModel.fromMap(Map<String, dynamic> map) {
    return JobModel(
      id: map['id'] as String,
      jobType: JobType.fromString(map['job_type'] as String),
      moduleType: map['module_type'] as String,
      status: JobStatus.fromString(map['status'] as String),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      inputJson: map['input_json'] as String?,
      outputJson: map['output_json'] as String?,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at'] as String) : null,
      finishedAt: map['finished_at'] != null ? DateTime.parse(map['finished_at'] as String) : null,
    );
  }
}
