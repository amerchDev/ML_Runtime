import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:mlruntime/src/mlcomputeunits.dart';

class MLModelConfiguration {
  late binding.MLModelConfiguration config;

  MLModelConfiguration(
      {MLComputeUnits computeUnits = MLComputeUnits.MLComputeUnitsAll}) {
    config = binding.MLModelConfiguration.alloc().init();
    config.computeUnits = computeUnits;
  }

  static MLModelConfiguration create() {
    return MLModelConfiguration();
  }

  static MLModelConfiguration createCPUConfig() {
    return MLModelConfiguration(
        computeUnits: MLComputeUnits.MLComputeUnitsCPUOnly);
  }

  static MLModelConfiguration createGPUConfig() {
    return MLModelConfiguration(
        computeUnits: MLComputeUnits.MLComputeUnitsCPUAndGPU);
  }

  static MLModelConfiguration createNPUConfig() {
    return MLModelConfiguration(
        computeUnits: MLComputeUnits.MLComputeUnitsCPUAndNeuralEngine);
  }

  MLComputeUnits get computeUnits {
    return config.computeUnits;
  }

  set computeUnits(MLComputeUnits units) {
    config.computeUnits = units;
  }
}
