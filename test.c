#include <elf.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>

int		main(void) {
	printf("%d\n", SEEK_END);
	printf("%d\n", SEEK_SET);
}
