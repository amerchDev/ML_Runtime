import 'dart:io';
import 'package:objective_c/objective_c.dart' as objc;

extension NSURL on File {
  objc.NSURL toNSURL() {
    return objc.NSURL.fileURLWithPath_(absolute.path.toNSString());
  }
}
