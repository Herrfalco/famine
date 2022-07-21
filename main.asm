				global		main
				extern		printf

fmt_s:
				db			"%s", 10, 0
fmt_ld:
				db			"%ld", 10, 0
print_s:
				lea			rdi,				[rel fmt_s]
				jmp			print
print_ld:
				lea			rdi,				[rel fmt_ld]
				jmp			print
print:
				call		printf
				ret


main:
code:
				push		rdi
				push		rsi
				push		rdx

				sub			rsp,				qword[rel buff_sz]	; buff @ 24
				sub			rsp,				24					; rdir_ret @ 16
																	; ent_off @ 8
																	; fd @ 0

				lea			rdi,				[rel test]
				mov			rsi,				qword[rel dir_o_flags]
				mov			rax,				2 ; open
				syscall

				mov			qword[rsp],			rax

				cmp			rax,				0
				jle			.end
.read_dir_loop:
				mov			rdi,				qword[rsp]
				lea			rsi,				[rsp+24]
				mov			rdx,				qword[rel buff_sz]
				mov			rax,				78 ; getdents
				syscall

				cmp			rax,				0
				jle			.read_dir_end

				mov			qword[rsp+16],		rax

				mov			qword[rsp+8], 		0
.entry_loop:
				mov			rbx,				qword[rsp+16]
				cmp			qword[rsp+8],		rbx
				je			.read_dir_end

				lea			rcx,				[rsp+24]
				add			rcx,				qword[rsp+8]

				lea			rsi,				[rcx+18]
				call		print_s

				lea			rcx,				[rsp+24]
				add			rcx,				qword[rsp+8]

				xor			rsi,				rsi
				mov			si,					word[rcx+16]
				add			qword[rsp+8],		rsi

				jmp			.entry_loop
.read_dir_end:
				mov			rdi,				qword[rsp]
				mov			rax,				3
				syscall
.end:
				add			rsp,				24
				add			rsp,				qword[rel buff_sz]

				pop			rdx
				pop			rsi
				pop			rdi

				xor			rax,				rax
				ret
code_end:
				
data:
dir_o_flags:
				dq			0x10000
test:
				db			"/tmp/test", 0
test2:
				db			"/tmp/test2", 0
buff_sz:
				dq			0x400
hello:
				db			"Hello World !", 10
hello_end:
data_end:
