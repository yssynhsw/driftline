import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ready = false;

void prepareDatabaseFactory() {
  if (_ready) {
    return;
  }
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  _ready = true;
}
