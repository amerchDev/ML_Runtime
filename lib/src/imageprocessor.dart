import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mlruntime/src/image.dart';
import 'package:mlruntime/binding/coreml.dart' as binding;
export 'package:mlruntime/binding/coreml.dart' show BitmapProcessorCopyMode;

class ImageProcessor implements Finalizable {
  late final binding.BitmapProcessor _processor;

  ImageProcessor() {
    _processor = binding.BitmapProcessor.alloc().init();
  }

  Future<(Image, (double, double))> copy(
      Image src, Image dst, binding.BitmapProcessorCopyMode mode) async {
    final worker = binding.BitmapProcessor.castFromPointer(
        _processor.retainAndReturnPointer());
    var completer = Completer();
    var handler = binding.ObjCBlock_ffiVoid.listener(() {
      completer.complete();
    });
    Pointer<binding.BitmapProcessCopyScale> data = calloc();
    worker.copyFrom_to_mode_handler_(data, src.image, dst.image, mode, handler);
    final double scaleX = data.ref.scaleX;
    final double scaleY = data.ref.scaleY;
    calloc.free(data);
    await completer.future;
    return (dst, (scaleX, scaleY));
  }

  Future<Image> blit(Image src, Image dst) async {
    final worker = binding.BitmapProcessor.castFromPointer(
        _processor.retainAndReturnPointer());
    var completer = Completer();
    var handler = binding.ObjCBlock_ffiVoid.listener(() {
      completer.complete();
    });
    worker.blitFrom_to_handler_(src.image, dst.image, handler);
    await completer.future;
    return dst;
  }

  Future<Image> scale(Image src, Image dst) async {
    final worker = binding.BitmapProcessor.castFromPointer(
        _processor.retainAndReturnPointer());
    var completer = Completer();
    var handler = binding.ObjCBlock_ffiVoid.listener(() {
      completer.complete();
    });
    worker.scaleFrom_to_handler_(src.image, dst.image, handler);
    await completer.future;
    return dst;
  }

  void dispose() {
    _processor.release();
  }
}
