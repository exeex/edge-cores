/* Edge32 stdout CSR feeds the JTAG console FIFO. No libc is required. */
volatile unsigned int characters_written = 0;

__attribute__((noinline)) void edge_putchar(unsigned int ch) {
    __asm__ volatile("csrw 0x7e1, %0" : : "r"(ch) : "memory");
}

int main(void) {
    const char *message = "Hello world from Edge32!\n";
    for (unsigned int i = 0; message[i] != '\0'; ++i) {
        edge_putchar((unsigned char)message[i]);
        characters_written = i + 1;
    }
    return 0;
}
