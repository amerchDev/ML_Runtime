
import 'package:objective_c/objective_c.dart' as objc;

extension NSArrayToDartArray on objc.NSArray {
  List<dynamic> toDartArray() {
    List<dynamic> results = List.filled(count, null);
    for (int i = 0; i < count; i++) {
      objc.ObjCObjectBase object = objectAtIndex_(i);
      if (objc.NSNumber.isInstance(object)) {
        results[i] = objc.NSNumber.castFrom(object);
      } else if (objc.NSString.isInstance(object)) {
        results[i] = objc.NSString.castFrom(object);
      } else {
        results[i] = object;
      }
    }
    return results;
  }

  List<int>? toIntList() {
    var data = toDartArray();
    if (data.any((obj) => !objc.NSNumber.isInstance(obj))) {
      return null;
    }
    return toDartArray()
        .map((dynamic obj) => (obj as objc.NSNumber).intValue)
        .toList(growable: false);
  }

  List<String>? toStringList() {
    var data = toDartArray();
    if (data.any((obj) => !objc.NSString.isInstance(obj))) {
      return null;
    }
    return toDartArray()
        .map((dynamic obj) => (obj as objc.NSString).toString())
        .toList(growable: false);
  }
}
