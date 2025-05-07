import 'dart:ffi';
import 'dart:typed_data';
import 'dart:collection';

import 'package:ffi/ffi.dart';
import 'package:quiver/check.dart';

import 'bindings/interpreter.dart';
import 'bindings/types.dart';
import 'ffi/helper.dart';
import 'quant.dart';
import 'util/list_shape_extension.dart';

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
    // Use Unmodifiable list to prevent modification of tensor data
    return UnmodifiableUint8List(
        Uint8List.fromList(tensorDataPtr.asTypedList(tensorByteSize)));
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
      Pointer<Float> dst =
          TfLiteInterpreterBindings.instance.getTensorData(_tensor).cast();
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

// Helper class to provide unmodifiable Uint8List view
class UnmodifiableUint8List extends UnmodifiableListView<int> implements Uint8List {
  final Uint8List _uint8list;

  UnmodifiableUint8List(Uint8List list) 
      : _uint8list = list,
        super(list);

  @override
  int get elementSizeInBytes => _uint8list.elementSizeInBytes;

  @override
  int get lengthInBytes => _uint8list.lengthInBytes;

  @override
  Uint8List buffer => _uint8list.buffer;

  @override
  ByteBuffer get buffer => _uint8list.buffer;

  @override
  int get offsetInBytes => _uint8list.offsetInBytes;

  @override
  Uint8List asUnmodifiableView() => UnmodifiableUint8List(_uint8list);

  @override
  Uint8List sublist(int start, [int? end]) {
    return UnmodifiableUint8List(_uint8list.sublist(start, end));
  }
} 