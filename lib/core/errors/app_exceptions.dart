/// Base exception for all application errors in NguyenDu Tool.
sealed class AppException implements Exception {
  final String message;
  final String? technicalDetails;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.technicalDetails, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message${technicalDetails != null ? ' ($technicalDetails)' : ''}';
}

/// Thrown when a file or workspace filesystem operation fails.
class FileException extends AppException {
  final String? path;
  const FileException(super.message, {this.path, super.technicalDetails, super.stackTrace});
}

/// Thrown when local SQLite database operations encounter an error.
class AppDatabaseException extends AppException {
  final String? query;
  const AppDatabaseException(super.message, {this.query, super.technicalDetails, super.stackTrace});
}

typedef DatabaseException = AppDatabaseException;

/// Thrown when an AI / TTS / OCR / Video provider operation fails.
class ProviderException extends AppException {
  final String? providerId;
  const ProviderException(super.message, {this.providerId, super.technicalDetails, super.stackTrace});
}

/// Thrown when a job execution or state transition fails.
class JobException extends AppException {
  final String? jobId;
  const JobException(super.message, {this.jobId, super.technicalDetails, super.stackTrace});
}

/// Thrown during app initialization / bootstrap phase.
class BootstrapException extends AppException {
  final String failedStep;
  const BootstrapException(super.message, {required this.failedStep, super.technicalDetails, super.stackTrace});
}

/// Base exception for Document Scanner operations.
class ScanException extends AppException {
  const ScanException(super.message, {super.technicalDetails, super.stackTrace});
}

class ScanImportException extends ScanException {
  const ScanImportException(super.message, {super.technicalDetails, super.stackTrace});
}

class ScanAcquisitionException extends ScanException {
  const ScanAcquisitionException(super.message, {super.technicalDetails, super.stackTrace});
}

class ScanExportException extends ScanException {
  const ScanExportException(super.message, {super.technicalDetails, super.stackTrace});
}

class ScanCancelledException extends ScanException {
  const ScanCancelledException(super.message, {super.technicalDetails, super.stackTrace});
}

/// Base exception for Text to Speech operations.
class TtsException extends AppException {
  const TtsException(super.message, {super.technicalDetails, super.stackTrace});
}

class TtsEngineUnavailableException extends TtsException {
  const TtsEngineUnavailableException(super.message, {super.technicalDetails, super.stackTrace});
}

class TtsVoiceUnavailableException extends TtsException {
  final String? voiceId;
  final String? voiceName;
  const TtsVoiceUnavailableException(
    super.message, {
    this.voiceId,
    this.voiceName,
    super.technicalDetails,
    super.stackTrace,
  });
}

class TtsSynthesisException extends TtsException {
  final int? chunkIndex;
  const TtsSynthesisException(super.message, {this.chunkIndex, super.technicalDetails, super.stackTrace});
}

class TtsEncodingException extends TtsException {
  const TtsEncodingException(super.message, {super.technicalDetails, super.stackTrace});
}

class TtsProviderAuthException extends TtsException {
  final String? providerId;
  const TtsProviderAuthException(super.message, {this.providerId, super.technicalDetails, super.stackTrace});
}

class TtsRateLimitException extends TtsException {
  final Duration? retryAfter;
  const TtsRateLimitException(super.message, {this.retryAfter, super.technicalDetails, super.stackTrace});
}

class TtsInputException extends TtsException {
  const TtsInputException(super.message, {super.technicalDetails, super.stackTrace});
}

class TtsCancelledException extends TtsException {
  const TtsCancelledException(super.message, {super.technicalDetails, super.stackTrace});
}

/// Thrown when secure storage (DPAPI) is unavailable or fails to initialize.
class SecureStorageUnavailableException extends AppException {
  const SecureStorageUnavailableException(super.message, {super.technicalDetails, super.stackTrace});
}

/// Thrown when legacy plaintext secret is detected or migration fails.
class LegacyPlaintextSecretDetectedException extends AppException {
  final String key;
  const LegacyPlaintextSecretDetectedException(super.message, {required this.key, super.technicalDetails, super.stackTrace});
}

/// Thrown when another running instance of the application holds the exclusive lock.
class SingleInstanceLockException extends AppException {
  const SingleInstanceLockException(super.message, {super.technicalDetails, super.stackTrace});
}

/// Thrown when primary database initialization fails due to file corruption.
class DatabaseCorruptBootstrapException extends AppException {
  final String databasePath;
  const DatabaseCorruptBootstrapException(super.message, {required this.databasePath, super.technicalDetails, super.stackTrace});
}

