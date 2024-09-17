/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#version 450 core

#define PRECISION ${PRECISION}

#define VEC4_T ${texel_type(DTYPE)}

#define op(X, Y, A) ${OPERATOR}

#include "broadcasting_utils.h"
#include "indexing_utils.h"

layout(std430) buffer;

${layout_declare_tensor(B, "w", "t_out", DTYPE, STORAGE)}
${layout_declare_tensor(B, "r", "t_in", DTYPE, STORAGE)}
${layout_declare_tensor(B, "r", "t_other", DTYPE, STORAGE)}
${layout_declare_ubo(B, "ivec4", "out_sizes")}
${layout_declare_ubo(B, "ivec4", "out_axis_map")}
${layout_declare_ubo(B, "ivec4", "in_sizes")}
${layout_declare_ubo(B, "ivec4", "in_axis_map")}
${layout_declare_ubo(B, "ivec4", "other_sizes")}
${layout_declare_ubo(B, "ivec4", "other_axis_map")}
${layout_declare_ubo(B, "ivec2", "broadcast_params")}
${layout_declare_ubo(B, "float", "alpha")}

layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

layout(constant_id = 3) const int packed_dim = C_DIM;

void main() {
  // pos is physical (x, y, z), as global workgroup uses image extents
  const ivec3 pos = ivec3(gl_GlobalInvocationID);
  // physical pos (x, y, z) -> logical (w, c, h, n) output
  const ivec4 idx = to_tensor_idx(pos, out_sizes, out_axis_map, packed_dim);

  if (any(greaterThanEqual(idx, out_sizes))) {
    return;
  }

  // broadcast on logical sizes
  ivec4 in_idx = broadcast_indices(idx, in_sizes);
  VEC4_T in_texel = VEC4_T(load_texel(
    t_in,
    // read axis mapped texel
    to_texture_pos(in_idx, in_sizes, in_axis_map, packed_dim)));

  // broadcast on logical sizes
  ivec4 other_idx = broadcast_indices(idx, other_sizes);
  VEC4_T other_texel = VEC4_T(load_texel(
    t_other,
    // read axis mapped texel
    to_texture_pos(other_idx, other_sizes, other_axis_map, packed_dim)));

  // Check boolean broadcast flags; we use ivec2 instead of bvec2 for alignment.
  if (broadcast_params.x > 0) {
    in_texel = in_texel.xxxx;
  }
  if (broadcast_params.y > 0) {
    other_texel = other_texel.xxxx;
  }

  imageStore(t_out,
    to_texture_pos(idx, out_sizes, out_axis_map, packed_dim),
    VEC4_T(op(in_texel, other_texel, alpha)));
}
