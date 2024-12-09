import 'package:mlruntime/mlruntime.dart' as mlruntime;
import 'dart:core';

// Split up detections of price tags into bins that are seperated by their y axis
List<List<mlruntime.DetectedObject>> binnedObjects(
    List<mlruntime.DetectedObject> objects,
    {int numBins = 10,
    required String expectedLabel}) {
  List<List<mlruntime.DetectedObject>> bins = [];

  // Initialize bins
  for (int i = 0; i < numBins; i++) {
    bins.add([]);
  }

  final double step = 1.0 / numBins;

  for (int i = 0; i < numBins; i++) {
    final double low = step * i;
    final double high = step * (i + 1);
    for (var object in objects) {
      if (object.classLabel != expectedLabel) continue;
      if (object.box.center.dy >= low && object.box.center.dy < high) {
        bins[i].add(object);
      }
    }
  }
  return bins;
}

mlruntime.DetectedObject? findSegmentTag(
  List<List<mlruntime.DetectedObject>> bins, {
  double tag1leftMargin = 0.25,
  double tag1RightMargin = 0.25,
}) {
  if (bins.first.length == 1) {
    return bins.first.first;
  } else if (bins.first.length == 2) {
    bins.first.sort((a, b) => a.box.center.dx.compareTo(b.box.center.dx));
    final (left, right) = (bins.first[0], bins.first[1]);

    // Accept first tag if the first tag is near the left edge and the second tag is near the right edge.
    if (left.box.center.dx < tag1leftMargin &&
        right.box.center.dx > (1.0 - tag1RightMargin)) {
      return left;
    }
  }

  return null;
}
