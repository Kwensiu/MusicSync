import 'package:music_sync/core/errors/app_exception.dart';

class FileAccessException extends AppException {
  FileAccessException(super.message, {super.code});
}
