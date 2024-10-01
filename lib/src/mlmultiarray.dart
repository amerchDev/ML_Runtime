import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:mlruntime/mlruntime.dart';
import 'package:objective_c/objective_c.dart' as objc;

export 'package:mlruntime/binding/coreml.dart' show MLMultiArrayDataType;

final class MLMultiArray implements Finalizable {
  final binding.MLMultiArray native;
  const MLMultiArray._(this.native);

  factory MLMultiArray.fromNative(binding.MLMultiArray native) {
    return MLMultiArray._(native);
  }

  factory MLMultiArray.zeroLike(MLMultiArray other) {
    return MLMultiArray.create(other.shape, other.dataType);
  }

  factory MLMultiArray.create(
      List<int> shape, binding.MLMultiArrayDataType dataType) {
    var array = objc.NSMutableArray.alloc().init();
    for (var dim in shape) {
      array.addObject_(objc.NSNumber.alloc().initWithInt_(dim));
    }
    Pointer<Pointer<objc.ObjCObject>> perror = calloc();
    final native = binding.MLMultiArray.alloc()
        .initWithShape_dataType_error_(array, dataType, perror);
    final error = perror.value;
    calloc.free(perror);

    if (native != null) {
      return MLMultiArray.fromNative(native);
    } else {
      final nserror = objc.NSError.castFromPointer(error);
      throw nserror;
    }
  }

  List<int> get shape {
    return native.shape.toIntList()!;
  }

  List<int> get strides {
    return native.strides.toIntList()!;
  }

  MLMultiArrayDataType get dataType {
    return native.dataType;
  }

  operator [](List<int> mdindex) {
    assert(mdindex.length == strides.length);
    int index = 0;
    for (int i = 0; i < mdindex.length; i++) {
      index += strides[i] * mdindex[i];
    }

    final nsnumber = native.objectAtIndexedSubscript_(index);
    switch (dataType) {
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeInt32:
        return nsnumber.intValue;
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeFloat16:
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeFloat32:
        return nsnumber.floatValue;
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeDouble:
        return nsnumber.doubleValue;
    }
  }

  operator []=(List<int> mdindex, num value) {
    assert(mdindex.length == strides.length);
    int index = 0;
    for (int i = 0; i < mdindex.length; i++) {
      index += strides[i] * mdindex[i];
    }

    switch (dataType) {
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeInt32:
        native.setObject_atIndexedSubscript_(
            objc.NSNumber.numberWithInt_(value as int), index);
        break;
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeFloat16:
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeFloat32:
        native.setObject_atIndexedSubscript_(
            objc.NSNumber.numberWithFloat_(value as double), index);
        break;
      case binding.MLMultiArrayDataType.MLMultiArrayDataTypeDouble:
        native.setObject_atIndexedSubscript_(
            objc.NSNumber.numberWithDouble_(value as double), index);
        break;
    }
  }
}
