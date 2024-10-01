import 'dart:async';
import 'dart:core';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mlruntime/globals.dart';

import '../binding/coreml.dart';

enum ImageFormat {
  argb(kCVPixelFormatType_32ARGB),
  bgra(kCVPixelFormatType_32BGRA);

  final int value;
  const ImageFormat(this.value);
}

final class Image implements Finalizable {
  final BitmapImage image;

  const Image._(this.image);

  static Image init(int width, int height) {
    return Image._(BitmapImage.alloc().initWithWidth_height_(width, height));
  }

  static Image initFromImage(
      Uint8List input, int width, int height, ImageFormat pixelFormatType) {
    var image = init(width, height);
    image.unsafeCopyFromRaw(input, pixelFormatType);
    return image;
  }

  void unsafeCopyFromRaw(Uint8List input, ImageFormat format) {
    lock(0);
    final addr = dataaddress;
    final width_ = width;
    final height_ = height;
    final (padLeft, padRight, padTop, padBottom) = padding;
    final output_ = addr.asTypedList(
        (width + padLeft + padRight) * (height + padTop + padBottom) * 4);
    final input_ = input;

    final Function(int, int) pixelMove;
    switch (format) {
      case ImageFormat.argb:
        pixelMove = (a, b) {
          output_[b + 0] = input_[a + 3];
          output_[b + 1] = input_[a + 2];
          output_[b + 2] = input_[a + 1];
          output_[b + 3] = input_[a + 0];
        };
        break;
      case ImageFormat.bgra:
        pixelMove = (a, b) {
          output_[b + 0] = input_[a + 0];
          output_[b + 1] = input_[a + 1];
          output_[b + 2] = input_[a + 2];
          output_[b + 3] = input_[a + 3];
        };
        break;
    }

    final bytesPerRow = padLeft + width_ + padRight;
    if (padLeft == 0 && padRight == 0 && padTop == 0 && padBottom == 0) {
      final length = bytesPerRow * height_ * 4;
      for (int i = 0; i < length; i += 4) {
        pixelMove(i, i);
      }
    } else {
      for (int row = 0; row < height_; row++) {
        for (int col = 0; col < width_; col++) {
          final indexIn = (row * width_ + col) * 4;
          final indexOut =
              (((row + padTop) * bytesPerRow) + (col + padLeft)) * 4;
          pixelMove(indexIn, indexOut);
        }
      }
    }
    unlock(0);
  }

  void _unsafeCopyToRawBGRA(Uint8List output) {
    lock(0);
    final addr = dataaddress;

    // Caching values since these properties perform FFI calls.
    final width_ = width;
    final height_ = height;
    final (padLeft, padRight, padTop, _) = padding;
    final bytesPerRow_ = padLeft + width_ + padRight;

    for (int row = 0; row < height_; row++) {
      for (int col = 0; col < width_; col++) {
        final indexIn = (((row + padTop) * bytesPerRow_) + (col + padLeft)) * 4;
        final indexOut = (row * width_ + col) * 4;

        output[indexOut + 0] = addr[indexIn + 0];
        output[indexOut + 1] = addr[indexIn + 1];
        output[indexOut + 2] = addr[indexIn + 2];
        output[indexOut + 3] = addr[indexIn + 3];
      }
    }
    unlock(0);
  }

  Future<ui.Image> intoUiImage({int? width, int? height}) async {
    Completer<ui.Image> completer = Completer<ui.Image>();
    Uint8List data = Uint8List(this.height * bytesPerRow);
    await Future.microtask(() {
      _unsafeCopyToRawBGRA(data);
    });

    ui.decodeImageFromPixels(
        data, this.width, this.height, ui.PixelFormat.bgra8888, (ui.Image ret) {
      completer.complete(ret);
    }, targetWidth: width, targetHeight: height);
    return await completer.future;
  }

  Pointer<CVBuffer> get cvpixelbuffer {
    return image.bitmap;
  }

  int get width {
    return image.width;
  }

  int get height {
    return image.height;
  }

  (int, int, int, int) get padding {
    Pointer<Size> left, right, top, bottom;
    left = calloc();
    right = calloc();
    top = calloc();
    bottom = calloc();
    coreML.CVPixelBufferGetExtendedPixels(
        image.bitmap, left, right, top, bottom);
    final ret = (left.value, right.value, top.value, bottom.value);
    calloc.free(left);
    calloc.free(right);
    calloc.free(top);
    calloc.free(bottom);
    return ret;
  }

  ImageFormat get pixelformat {
    switch (image.pixelFormat) {
      case kCVPixelFormatType_32ABGR:
        return ImageFormat.argb;
      case kCVPixelFormatType_32BGRA:
        return ImageFormat.bgra;
    }
    return ImageFormat.bgra;
  }

  int get bytesPerRow {
    return image.bytesPerRow;
  }

  Pointer<Uint8> get dataaddress {
    return image.data;
  }

  void lock(int lockFlags) {
    image.lock_(lockFlags == 0 ? false : true);
  }

  void unlock(int lockFlags) {
    image.unlock_(lockFlags == 0 ? false : true);
  }
}
