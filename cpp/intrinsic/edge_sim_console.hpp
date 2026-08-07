#ifndef EDGE_SIM_CONSOLE_HPP
#define EDGE_SIM_CONSOLE_HPP

#include <stdarg.h>
#include <stdint.h>

#include "edge_intrinsic.hpp"

namespace edge_sim_console_detail {

using edge_size_t = __SIZE_TYPE__;
using edge_ptrdiff_t = __PTRDIFF_TYPE__;

struct Writer {
    int count;

    void put(char ch)
    {
        edge_sim_putchar(ch);
        ++count;
    }

    void repeat(char ch, int n)
    {
        while (n-- > 0)
            put(ch);
    }
};

enum class Length {
    normal,
    hh,
    h,
    l,
    ll,
    z,
};

static inline uint64_t unsigned_arg(va_list *args, Length length)
{
    switch (length) {
    case Length::hh: return (unsigned char)va_arg(*args, unsigned);
    case Length::h: return (unsigned short)va_arg(*args, unsigned);
    case Length::l: return va_arg(*args, unsigned long);
    case Length::ll: return va_arg(*args, unsigned long long);
    case Length::z: return va_arg(*args, edge_size_t);
    default: return va_arg(*args, unsigned);
    }
}

static inline int64_t signed_arg(va_list *args, Length length)
{
    switch (length) {
    case Length::hh: return (signed char)va_arg(*args, int);
    case Length::h: return (short)va_arg(*args, int);
    case Length::l: return va_arg(*args, long);
    case Length::ll: return va_arg(*args, long long);
    case Length::z: return (int64_t)va_arg(*args, edge_ptrdiff_t);
    default: return va_arg(*args, int);
    }
}

static inline unsigned encode_unsigned(char *end, uint64_t value,
                                       unsigned base, bool uppercase)
{
    const char *alphabet = uppercase ? "0123456789ABCDEF"
                                     : "0123456789abcdef";
    char *cursor = end;
    do {
        *--cursor = alphabet[value % base];
        value /= base;
    } while (value != 0u);
    const unsigned length = (unsigned)(end - cursor);
    for (unsigned i = 0; i < length; ++i)
        end[-(int)length + (int)i] = cursor[i];
    return length;
}

static inline void emit_number(Writer &writer, uint64_t magnitude,
                               bool negative, unsigned base, bool uppercase,
                               bool alternate, bool plus, bool space,
                               bool left, bool zero, int width, int precision,
                               bool precision_specified)
{
    char digits[32];
    unsigned digit_count = encode_unsigned(digits + sizeof(digits), magnitude,
                                           base, uppercase);
    char *digit_begin = digits + sizeof(digits) - digit_count;
    if (precision_specified && precision == 0 && magnitude == 0)
        digit_count = 0;

    char sign = negative ? '-' : (plus ? '+' : (space ? ' ' : '\0'));
    char prefix0 = '\0';
    char prefix1 = '\0';
    if (alternate && base == 16u && magnitude != 0u) {
        prefix0 = '0';
        prefix1 = uppercase ? 'X' : 'x';
    } else if (alternate && base == 8u &&
               (magnitude != 0u || digit_count == 0u)) {
        prefix0 = '0';
    }
    const int prefix_count = (sign != '\0') + (prefix0 != '\0') +
                             (prefix1 != '\0');
    int leading_zeroes = precision_specified && precision > (int)digit_count
                             ? precision - (int)digit_count
                             : 0;
    int padding = width - prefix_count - leading_zeroes - (int)digit_count;
    if (padding < 0)
        padding = 0;
    if (zero && !left && !precision_specified) {
        leading_zeroes += padding;
        padding = 0;
    }

    if (!left)
        writer.repeat(' ', padding);
    if (sign != '\0')
        writer.put(sign);
    if (prefix0 != '\0')
        writer.put(prefix0);
    if (prefix1 != '\0')
        writer.put(prefix1);
    writer.repeat('0', leading_zeroes);
    for (unsigned i = 0; i < digit_count; ++i)
        writer.put(digit_begin[i]);
    if (left)
        writer.repeat(' ', padding);
}

} // namespace edge_sim_console_detail

static inline int edge_sim_vprintf(const char *format, va_list args)
{
    using namespace edge_sim_console_detail;
    Writer writer{0};
    va_list ap;
    va_copy(ap, args);

    while (*format != '\0') {
        if (*format != '%') {
            writer.put(*format++);
            continue;
        }
        ++format;

        bool left = false;
        bool plus = false;
        bool space = false;
        bool alternate = false;
        bool zero = false;
        bool parsing_flags = true;
        while (parsing_flags) {
            switch (*format) {
            case '-': left = true; ++format; break;
            case '+': plus = true; ++format; break;
            case ' ': space = true; ++format; break;
            case '#': alternate = true; ++format; break;
            case '0': zero = true; ++format; break;
            default: parsing_flags = false; break;
            }
        }

        int width = 0;
        if (*format == '*') {
            width = va_arg(ap, int);
            ++format;
            if (width < 0) {
                left = true;
                width = -width;
            }
        } else {
            while (*format >= '0' && *format <= '9')
                width = width * 10 + (*format++ - '0');
        }

        bool precision_specified = false;
        int precision = 0;
        if (*format == '.') {
            precision_specified = true;
            ++format;
            if (*format == '*') {
                precision = va_arg(ap, int);
                ++format;
                if (precision < 0)
                    precision_specified = false;
            } else {
                while (*format >= '0' && *format <= '9')
                    precision = precision * 10 + (*format++ - '0');
            }
        }

        Length length = Length::normal;
        if (*format == 'h') {
            length = Length::h;
            if (*++format == 'h') {
                length = Length::hh;
                ++format;
            }
        } else if (*format == 'l') {
            length = Length::l;
            if (*++format == 'l') {
                length = Length::ll;
                ++format;
            }
        } else if (*format == 'z') {
            length = Length::z;
            ++format;
        }

        const char conversion = *format == '\0' ? '\0' : *format++;
        switch (conversion) {
        case '%': writer.put('%'); break;
        case 'c': {
            const char ch = (char)va_arg(ap, int);
            if (!left) writer.repeat(' ', width > 1 ? width - 1 : 0);
            writer.put(ch);
            if (left) writer.repeat(' ', width > 1 ? width - 1 : 0);
            break;
        }
        case 's': {
            const char *text = va_arg(ap, const char *);
            if (text == nullptr) text = "(null)";
            int length_value = 0;
            while (text[length_value] != '\0' &&
                   (!precision_specified || length_value < precision))
                ++length_value;
            if (!left) writer.repeat(' ', width > length_value
                                          ? width - length_value : 0);
            for (int i = 0; i < length_value; ++i) writer.put(text[i]);
            if (left) writer.repeat(' ', width > length_value
                                         ? width - length_value : 0);
            break;
        }
        case 'd':
        case 'i': {
            const int64_t value = signed_arg(&ap, length);
            const bool negative = value < 0;
            const uint64_t magnitude = negative
                ? (uint64_t)(-(value + 1)) + 1u : (uint64_t)value;
            emit_number(writer, magnitude, negative, 10u, false, false,
                        plus, space, left, zero, width, precision,
                        precision_specified);
            break;
        }
        case 'u':
        case 'o':
        case 'x':
        case 'X': {
            const unsigned base = conversion == 'o' ? 8u
                                  : (conversion == 'u' ? 10u : 16u);
            emit_number(writer, unsigned_arg(&ap, length), false, base,
                        conversion == 'X', alternate, false, false, left,
                        zero, width, precision, precision_specified);
            break;
        }
        case 'p': {
            const uintptr_t value = (uintptr_t)va_arg(ap, void *);
            emit_number(writer, value, false, 16u, false, true, false, false,
                        left, zero, width, precision, precision_specified);
            break;
        }
        case 'f': case 'F': case 'e': case 'E': case 'g': case 'G':
            (void)va_arg(ap, double);
            for (const char *text = "<float?>"; *text; ++text)
                writer.put(*text);
            break;
        case '\0': --format; break;
        default:
            writer.put('%');
            writer.put(conversion);
            break;
        }
    }
    va_end(ap);
    return writer.count;
}

static inline int edge_sim_printf(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    const int count = edge_sim_vprintf(format, args);
    va_end(args);
    return count;
}

// Freestanding software can call printf directly.  Keep the implementation
// inline so tests that do not print pull in no formatter code.
static inline int printf(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    const int count = edge_sim_vprintf(format, args);
    va_end(args);
    return count;
}

#endif
