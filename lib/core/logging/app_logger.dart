import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static void fine(String message) {
    developer.log(message, level: 500);
  }

  static void warning(String message) {
    developer.log(message, level: 900);
  }

  static void severe(String message) {
    developer.log(message, level: 1000);
  }
}
