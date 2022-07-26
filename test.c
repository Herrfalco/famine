#include <elf.h>
#include <stdio.h>

int		main(void) {
	printf("%ld\n", sizeof(Elf64_Shdr));
}
