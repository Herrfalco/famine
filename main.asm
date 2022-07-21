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
				push		rdi
				push		rsi
				push		rdx

				sub			rsp,				2048				; path_buff @ 1064
				sub			rsp,				40					; dir_buff @ 40
																	; test2 @ 24
																	; rdir_ret @ 16
																	; ent_off @ 8
																	; fd @ 0

				mov			qword[rsp+24],		0
				lea			rdi,				[rel test]
.read_dir_loop:
				mov			rsi,				qword[rel dir_o_flags]
				mov			rax,				2 ; open
				syscall

				mov			qword[rsp],			rax

				cmp			rax,				0
				jle			.end

				mov			rdi,				qword[rsp]
				lea			rsi,				[rsp+40]
				mov			rdx,				1024
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

				lea			rcx,				[rsp+40]
				add			rcx,				qword[rsp+8]

				lea			rdi,				[rcx+18]
				lea			rsi,				[rel curent_dir]
				call		str_cmp

				cmp			rax,				0
				je			.after_print

				lea			rdi,				[rcx+18]
				lea			rsi,				[rel parent_dir]
				call		str_cmp

				cmp			rax,				0
				je			.after_print

				mov			rax,				rcx
				xor			rbx,				rbx
				mov			bx,					word[rcx+16]
				add			rax,				rbx
				dec			rax
				cmp			byte[rax],			8					; DT_REG
				jne			.after_print

				lea			rsi,				[rcx+18]
				call		print_s
.after_print:
				lea			rcx,				[rsp+40]
				add			rcx,				qword[rsp+8]

				xor			rsi,				rsi
				mov			si,					word[rcx+16]
				add			qword[rsp+8],		rsi

				jmp			.entry_loop
.read_dir_end:
				mov			rdi,				qword[rsp]
				mov			rax,				3
				syscall

				cmp			qword[rsp+24],		1
				je			.end

				inc			qword[rsp+24]

				lea			rdi,				[rel test2]
				jmp			.read_dir_loop
.end:
				add			rsp,				40
				add			rsp,				2048

				pop			rdx
				pop			rsi
				pop			rdi

				xor			rax,				rax
				ret
str_cmp:
				xor			rax,				rax
.loop:
				mov			al,					byte[rdi]
				cmp			al,					0
				je			.end

				cmp			al,					byte[rsi]
				jne			.end

				inc			rdi
				inc			rsi
				jmp			.loop
.end:
				sub			al,					byte[rsi]
				ret
concat_path:
				lea			rax,				[rsp+1064]
.loop_1:
				mov			bl,					byte[rdi]
				cmp			bl,					0
				je			.loop_2

				mov			byte[rax],			bl
				inc			rdi
				inc			rax
				jmp			.loop_1
.loop_2:
				mov			bl,					byte[rsi]
				cmp			bl,					0
				je			.end

				mov			byte[rax],			bl
				inc			rdi
				inc			rax
				jmp			.loop_2
.end:
				ret
main_end:
				
data:
dir_o_flags:
				dq			0x10000
test:
				db			"/tmp/test", 0
test2:
				db			"/tmp/test2", 0
curent_dir:
				db			".", 0
parent_dir:
				db			"..", 0
hello:
				db			"Hello World !", 10
hello_end:
data_end:
