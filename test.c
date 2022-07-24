#include <sys/mman.h>
#include <stdio.h>

int			main(void) {
	printf("%d\n", PROT_READ | PROT_WRITE | PROT_EXEC);
}
