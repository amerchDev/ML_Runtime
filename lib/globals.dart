import 'dart:ffi';

import 'binding/coreml.dart';

final CoreML coreML = CoreML(DynamicLibrary.process());
