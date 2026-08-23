/* Minimal BAR0 word read/write. Driver must be unloaded.
 * Usage: bar0rw <bdf> rd <offset>
 *        bar0rw <bdf> wr <offset> <value>
 */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define BAR0_SIZE (16u << 20)

int main(int argc, char **argv)
{
    char path[128];
    int fd;
    volatile uint32_t *bar0;
    uint32_t off, val;
    const char *bdf, *op;

    if (argc < 4) {
        fprintf(stderr, "usage: %s <bdf> rd <off> | wr <off> <val>\n", argv[0]);
        return 2;
    }
    bdf = argv[1];
    op = argv[2];
    off = (uint32_t)strtoul(argv[3], NULL, 0);
    snprintf(path, sizeof(path), "/sys/bus/pci/devices/%s/resource0", bdf);
    fd = open(path, O_RDWR | O_SYNC);
    if (fd < 0) {
        perror(path);
        return 1;
    }
    bar0 = mmap(NULL, BAR0_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (bar0 == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    if (strcmp(op, "rd") == 0) {
        printf("0x%08x\n", bar0[off / 4]);
    } else if (strcmp(op, "wr") == 0 && argc >= 5) {
        val = (uint32_t)strtoul(argv[4], NULL, 0);
        bar0[off / 4] = val;
        __sync_synchronize();
        printf("0x%08x\n", bar0[off / 4]);
    } else {
        fprintf(stderr, "bad op\n");
        return 2;
    }
    munmap((void *)bar0, BAR0_SIZE);
    close(fd);
    return 0;
}
