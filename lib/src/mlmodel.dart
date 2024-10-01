import 'dart:async';
import 'package:flutter/services.dart';
import 'package:mlruntime/mlruntime.dart';

import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:mlruntime/src/io/mlpackagemanifest.dart';
import 'package:mlruntime/src/io/path.dart';
import 'package:objective_c/objective_c.dart' as objc;

class MLModel {
  binding.MLModel native;
  MLModel.native(this.native);

  static Future<MLModel?> fromBundle(
      AssetBundle bundle, String assetKey, MLModelConfiguration config) async {
    var package = await MLPackageManifest.loadFromBundle(bundle, assetKey);
    if (package == null) {
      return null;
    }
    final model =
        await _loadModelURLAndConfiguration(package.model.toNSURL(), config);

    package.dispose();
    if (model == null) {
      return null;
    }
    return MLModel.native(model);
  }

  static Future<objc.NSURL?> _compileModel(objc.NSURL url) async {
    var completer = Completer<objc.NSURL?>();
    var handler = binding.ObjCBlock_ffiVoid_NSURL_NSError.listener(
        (objc.NSURL? modelURL, objc.NSError? error) {
      completer.complete(modelURL);
    });
    binding.MLModel.compileModelAtURL_completionHandler_(url, handler);
    return await completer.future;
  }

  static Future<binding.MLModel?> _loadModelURLAndConfiguration(
      objc.NSURL url, MLModelConfiguration config) async {
    var compiledModel = await _compileModel(url);
    if (compiledModel == null) {
      return null;
    }

    var completer = Completer<binding.MLModel?>();
    var handler = binding.ObjCBlock_ffiVoid_MLModel_NSError.listener(
        (binding.MLModel? model, objc.NSError? error) {
      completer.complete(model);
    });
    binding.MLModel.loadContentsOfURL_configuration_completionHandler_(
        compiledModel, config.config, handler);
    return await completer.future;
  }

  Future<objc.NSObject> predictFromFeatures(objc.NSObject input) async {
    var completer = Completer<(objc.NSObject?, objc.NSError?)>();
    var completionHandler =
        binding.ObjCBlock_ffiVoid_objcObjCObject_NSError.listener(
            (objc.ObjCObjectBase? obj, objc.NSError? err) {
      var obj_ = obj != null ? objc.NSObject.castFrom(obj) : null;
      completer.complete((obj_, err));
    });
    native.predictionFromFeatures_completionHandler_(input, completionHandler);
    var (val, err) = await completer.future;
    if (val != null) {
      return val;
    } else {
      throw err!.localizedDescription;
    }
  }
}
