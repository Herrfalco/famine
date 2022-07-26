#include <elf.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>

int		main(void) {
	printf("%d\n", PROT_READ | PROT_WRITE | PROT_EXEC);
}
