// Integration sentinel: use the pinned libnn directly, without NNC lowering.
#include "libnn/matmul.hpp"

using Bf16 = nnedge::bfloat16_t;
using nnedge::Shape;
using nnedge::Tensor;

constexpr unsigned kK = 16;
constexpr unsigned kN = 16;
constexpr unsigned kMaxRows = 9;
constexpr unsigned kMaxHeads = 2;
alignas(64) static Bf16 lhs_data[kMaxHeads * kMaxRows * kK];
alignas(64) static Bf16 rhs_data[kMaxHeads * kK * kN];
alignas(64) static Bf16 output_data[kMaxHeads * kMaxRows * kN];

// Small integer products and sums are exactly representable in BF16. Compute
// the golden independently of libnn's reference helper and packing functions.
static int lhs_value(unsigned head, unsigned row, unsigned k)
{
    return static_cast<int>((head * 3 + row * 2 + k) % 5) - 2;
}

static int rhs_value(unsigned head, unsigned k, unsigned col)
{
    return static_cast<int>((head + k * 2 + col) % 3) - 1;
}

static int run_case(unsigned rows, unsigned heads, bool transposed)
{
    const unsigned lhs_count = heads * rows * kK;
    const unsigned rhs_count = heads * kK * kN;
    const unsigned output_count = heads * rows * kN;
    for (unsigned h = 0; h < heads; ++h) {
        for (unsigned r = 0; r < rows; ++r) {
            for (unsigned k = 0; k < kK; ++k) {
                const unsigned i = transposed ? r * heads * kK + h * kK + k
                                             : (h * rows + r) * kK + k;
                lhs_data[i] = Bf16::from_float(lhs_value(h, r, k));
            }
        }
        for (unsigned k = 0; k < kK; ++k) {
            for (unsigned c = 0; c < kN; ++c) {
                const unsigned i = transposed ? c * heads * kK + h * kK + k
                                             : k * heads * kN + h * kN + c;
                rhs_data[i] = Bf16::from_float(rhs_value(h, k, c));
            }
        }
    }
    for (unsigned i = 0; i < output_count; ++i)
        output_data[i] = Bf16::from_bits(0xdead);

    nnedge::reset_allocator();
    const Shape lhs_shape = transposed ? Shape(rows, heads * kK)
                           : heads == 1 ? Shape(rows, kK) : Shape(heads, rows, kK);
    const Shape rhs_shape = transposed ? Shape(kN, heads * kK) : Shape(kK, heads * kN);
    const Shape output_shape = transposed ? Shape(heads, rows, kN) : Shape(rows, heads * kN);
    Tensor<Bf16> lhs(lhs_shape, lhs_data);
    Tensor<Bf16> rhs(rhs_shape, rhs_data);
    Tensor<Bf16> output(output_shape, output_data);
    edge_dcache_clean_range(lhs_data, lhs_count * sizeof(Bf16));
    edge_dcache_clean_range(rhs_data, rhs_count * sizeof(Bf16));
    if (transposed)
        nnedge::op::matmul_transpose(output, lhs, rhs, heads);
    else
        nnedge::op::matmul(output, lhs, rhs, heads);
    if (nnedge::alloc_failed()) {
        edge_sim_printf("MATMUL_INTERFACE FAIL allocation\n");
        return 1;
    }
    edge_dcache_invalidate_range(output_data, output_count * sizeof(Bf16));
    for (unsigned h = 0; h < heads; ++h) {
        for (unsigned r = 0; r < rows; ++r) {
            for (unsigned c = 0; c < kN; ++c) {
                int expected = 0;
                for (unsigned k = 0; k < kK; ++k)
                    expected += lhs_value(h, r, k) * rhs_value(h, k, c);
                const unsigned i = transposed ? (h * rows + r) * kN + c
                                             : r * heads * kN + h * kN + c;
                const auto bits = Bf16::from_float(expected).bits;
                if (output_data[i].bits != bits) {
                    edge_sim_printf("MATMUL_INTERFACE FAIL transpose=%u heads=%u rows=%u index=%u got=%x expected=%x\n",
                                    transposed, heads, rows, i, output_data[i].bits, bits);
                    return 1;
                }
            }
        }
    }
    edge_sim_printf("MATMUL_INTERFACE case PASS transpose=%u heads=%u rows=%u values=%u\n",
                    transposed, heads, rows, output_count);
    return 0;
}

extern "C" int main(void)
{
    for (unsigned transposed = 0; transposed < 2; ++transposed) {
        if (run_case(8, 1, transposed) || run_case(8, 2, transposed) ||
            run_case(9, 2, transposed))
            return 1;
    }
    edge_sim_printf("MATMUL_INTERFACE PASS cases=6\n");
    return 0;
}
