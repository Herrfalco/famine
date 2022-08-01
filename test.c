#include <elf.h>
#include <stdio.h>

int		main(void) { 
	printf("%ld\n\n", sizeof(Elf64_Ehdr));
	return (0);
}
