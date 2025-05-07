import 'dart:ffi';
import 'dart:typed_data';
import 'dart:collection';

import 'package:ffi/ffi.dart';

import 'bindings/interpreter.dart';
import 'bindings/types.dart';
import 'ffi/helper.dart';
import 'quant.dart';

class Tensor {
  final Pointer<TfLiteTensor> _tensor;
  final bool _deleted;

  Tensor(this._tensor) : _deleted = false;

  Tensor._(this._tensor, this._deleted);

  /// Name of the tensor element.
  String get name => TfLiteInterpreterBindings.instance.getTensorName(_tensor).toDartString();

  /// Data type of the tensor element.
  TfLiteType get type => TfLiteInterpreterBindings.instance.getTensorType(_tensor);

  /// Dimensions of the tensor.
  List<int> get shape {
    final tensor = _tensor;
    final numDims = TfLiteInterpreterBindings.instance.getTensorNumDims(tensor);
    final dims = <int>[];
    for (var i = 0; i < numDims; i++) {
      dims.add(TfLiteInterpreterBindings.instance.getTensorDim(tensor, i));
    }
    return dims;
  }

  /// Underlying data buffer as bytes.
  Uint8List get data {
    final tensorByteSize = TfLiteInterpreterBindings.instance.getTensorByteSize(_tensor);
    final tensorDataPtr = TfLiteInterpreterBindings.instance.getTensorData(_tensor);
    return UnmodifiableList(Uint8List.fromList(tensorDataPtr.asTypedList(tensorByteSize)));
  }

  /// Quantization params for this tensor.
  QuantizationParams? get params => TfLiteInterpreterBindings.instance
      .getTensorQuantizationParams(_tensor)
      .asQuant;

  int get byteSize => TfLiteInterpreterBindings.instance.getTensorByteSize(_tensor);

  bool get isDynamic => TfLiteInterpreterBindings.instance.tensorIsDynamic(_tensor) == 1;

  @override
  String toString() {
    return 'Tensor{name: $name, type: $type, shape: $shape, data: ${data.length} bytes, params: $params}';
  }

  /// Updates the underlying data buffer with new bytes.
  /// This is only valid for non-dynamic tensors.
  ///
  /// The shape must match the current shape.
  void setTo(List<double> src) {
    checkArgument(!isDynamic, message: 'Not supported for dynamic tensors');
    if (type != TfLiteType.kTfLiteFloat32) {
      throw ArgumentError('setTo for double is only supported for float32 tensors');
    }

    final count = src.length;
    if (count != shape.computeNumElements()) {
      throw ArgumentError(
          'Tensor mismatch: can\'t copy $count elements to tensor with ${shape.computeNumElements()} elements');
    }
    final srcPtr = calloc<Float>(count);
    try {
      final dst = TfLiteInterpreterBindings.instance.getTensorData(_tensor).cast<Float>();
      for (var i = 0; i < count; i++) {
        srcPtr[i] = src[i];
      }
      // TODO: Move this to bindings (use memcpy)
      for (var i = 0; i < count; i++) {
        dst[i] = srcPtr[i];
      }
      print('copied $count elements to tensor');
    } finally {
      calloc.free(srcPtr);
    }
  }

  void dispose() {
    // TODO: Any dispose needed?
  }
} 