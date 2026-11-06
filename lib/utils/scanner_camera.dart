import 'dart:typed_data';
import 'package:flutter/widgets.dart';

abstract class ScannerCamera {
  Future<void> initialize();
  Widget buildPreview();
  Future<Uint8List> capture();
  Future<void> dispose();
}
