#include <elf.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>

int		main(void) {
	printf("%d\n", open("test", O_WRONLY));
	return (0);
}
