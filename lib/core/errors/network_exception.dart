import 'package:music_sync/core/errors/app_exception.dart';

class NetworkException extends AppException {
  NetworkException(super.message, {super.code});
}
