// UNSUPPORTED: asan
// RUN: mlir-opt %s -test-transform-dialect-erase-schedule -linalg-bufferize -arith-bufferize \
// RUN: -tensor-bufferize -func-bufferize -finalizing-bufferize -buffer-deallocation -convert-linalg-to-loops -convert-scf-to-cf \
// RUN: -convert-linalg-to-llvm -expand-strided-metadata -lower-affine -convert-arith-to-llvm -convert-scf-to-cf --convert-memref-to-llvm -convert-func-to-llvm -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_lib_dir/libmlir_c_runner_utils%shlibext,%mlir_lib_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -test-transform-dialect-interpreter -test-transform-dialect-erase-schedule -linalg-bufferize \
// RUN: -scf-bufferize -arith-bufferize -tensor-bufferize \
// RUN: -func-bufferize \
// RUN: -finalizing-bufferize -convert-linalg-to-loops -convert-scf-to-cf -convert-scf-to-cf \
// RUN: -convert-linalg-to-llvm -expand-strided-metadata -lower-affine -convert-arith-to-llvm -convert-scf-to-cf --convert-memref-to-llvm -convert-func-to-llvm -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_lib_dir/libmlir_c_runner_utils%shlibext,%mlir_lib_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

func.func @main() {
  %A = arith.constant dense<[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]> : tensor<2x3xf32>
  %B = arith.constant dense<[[1.0, 2.0, 3.0, 4.0],
                       [5.0, 6.0, 7.0, 8.0],
                       [9.0, 10.0, 11.0, 12.0]]> : tensor<3x4xf32>
  %C = arith.constant dense<1000.0> : tensor<2x4xf32>

  %D = linalg.matmul ins(%A, %B: tensor<2x3xf32>, tensor<3x4xf32>)
                     outs(%C: tensor<2x4xf32>) -> tensor<2x4xf32>

  %unranked = tensor.cast %D : tensor<2x4xf32> to tensor<*xf32>
  call @printMemrefF32(%unranked) : (tensor<*xf32>) -> ()

  //      CHECK: Unranked Memref base@ = {{0x[-9a-f]*}}
  // CHECK-SAME: rank = 2 offset = 0 sizes = [2, 4] strides = [4, 1] data =
  // CHECK-NEXT: [1038,   1044,   1050,   1056]
  // CHECK-NEXT: [1083,   1098,   1113,   1128]

  return
}

transform.sequence failures(propagate) {
  ^bb0(%arg1: !pdl.operation):
    %0 = transform.structured.match ops{["linalg.matmul"]} in %arg1 : (!pdl.operation) -> !pdl.operation
    %1, %loops:3 = transform.structured.tile %0 [1, 2, 3] : (!pdl.operation) -> (!pdl.operation, !pdl.operation, !pdl.operation, !pdl.operation)
}

func.func private @printMemrefF32(%ptr : tensor<*xf32>)
