#include "intrinsic/edge_sim_console.hpp"
#include "intrinsic/edge_intrinsic.hpp"

static void print_fp4_value(float value)
{
    int twice = static_cast<int>(value * 2.0f);
    if (twice < 0) {
        printf("-");
        twice = -twice;
    }
    printf("%d.%d", twice / 2, (twice % 2) * 5);
}

static float make_value(int element_id)
{
    // All input generation and arithmetic happens in ordinary FP32.
    return (static_cast<float>(element_id % 8) - 3.0f) * 0.5f;
}

extern "C" int main(void)
{
    printf("[1] Random-access set/get\n");
    fp4x16_t random_access = {0};
    const float random_value_3 = (1.0f + 2.0f) * 0.5f;
    const float random_value_12 = -1.5f * 2.0f;
    set_element_fp4(random_access, random_value_3, 3);
    set_element_fp4(random_access, random_value_12, 12);
    printf("idx3=");
    print_fp4_value(get_element_fp4(random_access, 3));
    printf(" idx12=");
    print_fp4_value(get_element_fp4(random_access, 12));
    printf(" packed=0x%016llx\n",
           static_cast<unsigned long long>(random_access.data));

    printf("[2] Full 16-element streaming pack\n");
    fp4x16_t partial = {0};
    for (int element_id = 0; element_id < 4; ++element_id)
        pack_next_fp4(partial, make_value(element_id));
    printf("after 4/16 (incomplete, do not store): 0x%016llx\n",
           static_cast<unsigned long long>(partial.data));

    fp4x16_t expected = {0};
    fp4x16_t streamed = {0};
    printf("FP32 source:");
    for (int element_id = 0; element_id < 16; ++element_id) {
        const float value = make_value(element_id);
        printf(" ");
        print_fp4_value(value);
        set_element_fp4(expected, value, element_id);
        pack_next_fp4(streamed, value);
    }
    printf("\n");

    printf("pack vs set: %s packed=0x%016llx\n",
           streamed.data == expected.data ? "MATCH" : "MISMATCH",
           static_cast<unsigned long long>(streamed.data));

    // A normal RV64 store exposes CUDA linear order in little-endian bytes.
    volatile fp4x16_t stored = {streamed.data};
    const volatile uint8_t *bytes =
        reinterpret_cast<const volatile uint8_t *>(&stored);
    printf("stored bytes:");
    for (int byte_id = 0; byte_id < 8; ++byte_id)
        printf(" %02x", static_cast<unsigned>(bytes[byte_id]));
    printf("\n");

    printf("[3] Sequential unpack to FP32\n");
    printf("FP32 decoded:");
    for (int element_id = 0; element_id < 16; ++element_id) {
        const float value = unpack_next_fp4(streamed);
        printf(" ");
        print_fp4_value(value);
    }
    printf(" remaining=0x%016llx\n",
           static_cast<unsigned long long>(streamed.data));

    return 0;
}
