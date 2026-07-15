	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_LLSEEK, 62
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_MMAP, 222
	.equ	AT_FDCWD, -100
	.equ	O_RDONLY, 0
	.equ	SEEK_SET, 0
	.equ	PROT_READ, 1
	.equ	PROT_WRITE, 2
	.equ	PROT_EXEC, 4
	.equ	MAP_PRIVATE, 0x02
	.equ	MAP_FIXED, 0x10
	.equ	AT_NULL, 0
	.equ	AT_PHDR, 3
	.equ	AT_PHENT, 4
	.equ	AT_PHNUM, 5
	.equ	AT_BASE, 7
	.equ	AT_ENTRY, 9
	.equ	PT_LOAD, 1
	.equ	PT_DYNAMIC, 2
	.equ	PT_PHDR, 6
	.equ	DT_NULL, 0
	.equ	DT_NEEDED, 1
	.equ	DT_PLTRELSZ, 2
	.equ	DT_HASH, 4
	.equ	DT_STRTAB, 5
	.equ	DT_SYMTAB, 6
	.equ	DT_STRSZ, 10
	.equ	DT_SYMENT, 11
	.equ	DT_INIT, 12
	.equ	DT_SONAME, 14
	.equ	DT_REL, 17
	.equ	DT_RELSZ, 18
	.equ	DT_RELENT, 19
	.equ	DT_PLTREL, 20
	.equ	DT_JMPREL, 23
	.equ	DT_INIT_ARRAY, 25
	.equ	DT_INIT_ARRAYSZ, 27
	.equ	DT_GNU_HASH, 0x6ffffef5
	.equ	DT_VERSYM, 0x6ffffff0
	.equ	DT_VERDEF, 0x6ffffffc
	.equ	DT_VERDEFNUM, 0x6ffffffd
	.equ	DT_VERNEED, 0x6ffffffe
	.equ	DT_VERNEEDNUM, 0x6fffffff
	.equ	ET_DYN, 3
	.equ	EM_RISCV, 0xf3
	.equ	R_RISCV_32, 1
	.equ	R_RISCV_RELATIVE, 3
	.equ	R_RISCV_JUMP_SLOT, 5
	.equ	MAX_NEEDED_OBJECTS, 8
	.equ	MAX_TRANSITIVE_NEEDED, 4
	.equ	NEEDED_OBJ_NAME_BYTES, 64
	.equ	NEEDED_DYNAMIC_BYTES, 256
	.equ	NEEDED_OBJ_STRTAB_BYTES, 512
	.equ	NEEDED_OBJ_SYMTAB_BYTES, 512
	.equ	TRANSITIVE_NAME_POOL_BYTES, MAX_TRANSITIVE_NEEDED * NEEDED_OBJ_NAME_BYTES
	.equ	TRANSITIVE_FRAME_BYTES, TRANSITIVE_NAME_POOL_BYTES + 48

	.section .rodata, "a"
start_msg:
	.ascii	"[ld-caribe] PT_INTERP handoff reached\n"
	.equ	start_msg_len, . - start_msg
argv0_msg:
	.ascii	"[ld-caribe] argv0: "
	.equ	argv0_msg_len, . - argv0_msg
entry_msg:
	.ascii	"[ld-caribe] AT_ENTRY main="
	.equ	entry_msg_len, . - entry_msg
base_msg:
	.ascii	"[ld-caribe] AT_BASE self="
	.equ	base_msg_len, . - base_msg
phdr_msg:
	.ascii	"[ld-caribe] AT_PHDR main="
	.equ	phdr_msg_len, . - phdr_msg
dynamic_msg:
	.ascii	"[ld-caribe] PT_DYNAMIC main="
	.equ	dynamic_msg_len, . - dynamic_msg
dynamic_absent_msg:
	.ascii	"<absent>\n"
	.equ	dynamic_absent_msg_len, . - dynamic_absent_msg
load_bias_msg:
	.ascii	"[ld-caribe] main load bias="
	.equ	load_bias_msg_len, . - load_bias_msg
dt_rel_msg:
	.ascii	"[ld-caribe] DT_REL main="
	.equ	dt_rel_msg_len, . - dt_rel_msg
dt_relsz_msg:
	.ascii	"[ld-caribe] DT_RELSZ main="
	.equ	dt_relsz_msg_len, . - dt_relsz_msg
dt_relent_msg:
	.ascii	"[ld-caribe] DT_RELENT main="
	.equ	dt_relent_msg_len, . - dt_relent_msg
dt_jmprel_msg:
	.ascii	"[ld-caribe] DT_JMPREL main="
	.equ	dt_jmprel_msg_len, . - dt_jmprel_msg
dt_pltrelsz_msg:
	.ascii	"[ld-caribe] DT_PLTRELSZ main="
	.equ	dt_pltrelsz_msg_len, . - dt_pltrelsz_msg
dt_pltrel_msg:
	.ascii	"[ld-caribe] DT_PLTREL main="
	.equ	dt_pltrel_msg_len, . - dt_pltrel_msg
dt_symtab_msg:
	.ascii	"[ld-caribe] DT_SYMTAB main="
	.equ	dt_symtab_msg_len, . - dt_symtab_msg
dt_strtab_msg:
	.ascii	"[ld-caribe] DT_STRTAB main="
	.equ	dt_strtab_msg_len, . - dt_strtab_msg
dt_strsz_msg:
	.ascii	"[ld-caribe] DT_STRSZ main="
	.equ	dt_strsz_msg_len, . - dt_strsz_msg
dt_syment_msg:
	.ascii	"[ld-caribe] DT_SYMENT main="
	.equ	dt_syment_msg_len, . - dt_syment_msg
dt_versym_msg:
	.ascii	"[ld-caribe] DT_VERSYM main="
	.equ	dt_versym_msg_len, . - dt_versym_msg
main_versym6_msg:
	.ascii	"[ld-caribe] MAIN VERSYM[6]="
	.equ	main_versym6_msg_len, . - main_versym6_msg
main_versym7_msg:
	.ascii	"[ld-caribe] MAIN VERSYM[7]="
	.equ	main_versym7_msg_len, . - main_versym7_msg
main_versym8_msg:
	.ascii	"[ld-caribe] MAIN VERSYM[8]="
	.equ	main_versym8_msg_len, . - main_versym8_msg
main_sym_versym_msg:
	.ascii	"[ld-caribe] MAIN sym versym="
	.equ	main_sym_versym_msg_len, . - main_sym_versym_msg
dt_needed_msg:
	.ascii	"[ld-caribe] DT_NEEDED main="
	.equ	dt_needed_msg_len, . - dt_needed_msg
dt_needed_count_msg:
	.ascii	"[ld-caribe] DT_NEEDED count="
	.equ	dt_needed_count_msg_len, . - dt_needed_count_msg
needed_name_msg:
	.ascii	"[ld-caribe] DT_NEEDED name="
	.equ	needed_name_msg_len, . - needed_name_msg
dt_soname_msg:
	.ascii	"[ld-caribe] DT_SONAME main="
	.equ	dt_soname_msg_len, . - dt_soname_msg
soname_name_msg:
	.ascii	"[ld-caribe] DT_SONAME name="
	.equ	soname_name_msg_len, . - soname_name_msg
dt_verneed_msg:
	.ascii	"[ld-caribe] DT_VERNEED main="
	.equ	dt_verneed_msg_len, . - dt_verneed_msg
dt_verneednum_msg:
	.ascii	"[ld-caribe] DT_VERNEEDNUM main="
	.equ	dt_verneednum_msg_len, . - dt_verneednum_msg
main_verneed_file_msg:
	.ascii	"[ld-caribe] VERNEED file="
	.equ	main_verneed_file_msg_len, . - main_verneed_file_msg
main_verneed_hash_msg:
	.ascii	"[ld-caribe] VERNEED hash="
	.equ	main_verneed_hash_msg_len, . - main_verneed_hash_msg
main_verneed_other_msg:
	.ascii	"[ld-caribe] VERNEED other="
	.equ	main_verneed_other_msg_len, . - main_verneed_other_msg
main_verneed_name_msg:
	.ascii	"[ld-caribe] VERNEED name="
	.equ	main_verneed_name_msg_len, . - main_verneed_name_msg
main_verneed_name_match_msg:
	.ascii	"[ld-caribe] VERNEED name match="
	.equ	main_verneed_name_match_msg_len, . - main_verneed_name_match_msg
main_verneed_match_msg:
	.ascii	"[ld-caribe] VERNEED provider match="
	.equ	main_verneed_match_msg_len, . - main_verneed_match_msg
needed_path_msg:
	.ascii	"[ld-caribe] load NEEDED path="
	.equ	needed_path_msg_len, . - needed_path_msg
needed_object_index_msg:
	.ascii	"[ld-caribe] NEEDED object index="
	.equ	needed_object_index_msg_len, . - needed_object_index_msg
needed_object_registered_msg:
	.ascii	"[ld-caribe] NEEDED object registered count="
	.equ	needed_object_registered_msg_len, . - needed_object_registered_msg
needed_duplicate_msg:
	.ascii	"[ld-caribe] NEEDED duplicate skip="
	.equ	needed_duplicate_msg_len, . - needed_duplicate_msg
needed_transitive_msg:
	.ascii	"[ld-caribe] NEEDED transitive name="
	.equ	needed_transitive_msg_len, . - needed_transitive_msg
needed_open_fail_msg:
	.ascii	"[ld-caribe] NEEDED open/read failed="
	.equ	needed_open_fail_msg_len, . - needed_open_fail_msg
needed_read_msg:
	.ascii	"[ld-caribe] NEEDED read bytes="
	.equ	needed_read_msg_len, . - needed_read_msg
needed_bad_elf_msg:
	.ascii	"[ld-caribe] NEEDED bad ELF\n"
	.equ	needed_bad_elf_msg_len, . - needed_bad_elf_msg
needed_type_msg:
	.ascii	"[ld-caribe] NEEDED e_type="
	.equ	needed_type_msg_len, . - needed_type_msg
needed_entry_msg:
	.ascii	"[ld-caribe] NEEDED e_entry="
	.equ	needed_entry_msg_len, . - needed_entry_msg
needed_phoff_msg:
	.ascii	"[ld-caribe] NEEDED e_phoff="
	.equ	needed_phoff_msg_len, . - needed_phoff_msg
needed_phnum_msg:
	.ascii	"[ld-caribe] NEEDED e_phnum="
	.equ	needed_phnum_msg_len, . - needed_phnum_msg
needed_dynamic_off_msg:
	.ascii	"[ld-caribe] NEEDED PT_DYNAMIC off="
	.equ	needed_dynamic_off_msg_len, . - needed_dynamic_off_msg
needed_dynamic_vaddr_msg:
	.ascii	"[ld-caribe] NEEDED PT_DYNAMIC vaddr="
	.equ	needed_dynamic_vaddr_msg_len, . - needed_dynamic_vaddr_msg
needed_dynamic_size_msg:
	.ascii	"[ld-caribe] NEEDED PT_DYNAMIC size="
	.equ	needed_dynamic_size_msg_len, . - needed_dynamic_size_msg
needed_dynamic_read_msg:
	.ascii	"[ld-caribe] NEEDED dynamic read bytes="
	.equ	needed_dynamic_read_msg_len, . - needed_dynamic_read_msg
needed_dt_strtab_msg:
	.ascii	"[ld-caribe] NEEDED DT_STRTAB="
	.equ	needed_dt_strtab_msg_len, . - needed_dt_strtab_msg
needed_dt_strsz_msg:
	.ascii	"[ld-caribe] NEEDED DT_STRSZ="
	.equ	needed_dt_strsz_msg_len, . - needed_dt_strsz_msg
needed_dt_hash_msg:
	.ascii	"[ld-caribe] NEEDED DT_HASH="
	.equ	needed_dt_hash_msg_len, . - needed_dt_hash_msg
needed_dt_gnuhash_msg:
	.ascii	"[ld-caribe] NEEDED DT_GNU_HASH="
	.equ	needed_dt_gnuhash_msg_len, . - needed_dt_gnuhash_msg
needed_dt_versym_msg:
	.ascii	"[ld-caribe] NEEDED DT_VERSYM="
	.equ	needed_dt_versym_msg_len, . - needed_dt_versym_msg
needed_dt_verdef_msg:
	.ascii	"[ld-caribe] NEEDED DT_VERDEF="
	.equ	needed_dt_verdef_msg_len, . - needed_dt_verdef_msg
needed_dt_verdefnum_msg:
	.ascii	"[ld-caribe] NEEDED DT_VERDEFNUM="
	.equ	needed_dt_verdefnum_msg_len, . - needed_dt_verdefnum_msg
needed_dt_verneed_msg:
	.ascii	"[ld-caribe] NEEDED DT_VERNEED="
	.equ	needed_dt_verneed_msg_len, . - needed_dt_verneed_msg
needed_dt_verneednum_msg:
	.ascii	"[ld-caribe] NEEDED DT_VERNEEDNUM="
	.equ	needed_dt_verneednum_msg_len, . - needed_dt_verneednum_msg
needed_dt_symtab_msg:
	.ascii	"[ld-caribe] NEEDED DT_SYMTAB="
	.equ	needed_dt_symtab_msg_len, . - needed_dt_symtab_msg
needed_dt_syment_msg:
	.ascii	"[ld-caribe] NEEDED DT_SYMENT="
	.equ	needed_dt_syment_msg_len, . - needed_dt_syment_msg
needed_dt_soname_msg:
	.ascii	"[ld-caribe] NEEDED DT_SONAME="
	.equ	needed_dt_soname_msg_len, . - needed_dt_soname_msg
needed_dt_needed_msg:
	.ascii	"[ld-caribe] NEEDED DT_NEEDED="
	.equ	needed_dt_needed_msg_len, . - needed_dt_needed_msg
needed_dt_needed_count_msg:
	.ascii	"[ld-caribe] NEEDED DT_NEEDED count="
	.equ	needed_dt_needed_count_msg_len, . - needed_dt_needed_count_msg
needed_dt_rel_msg:
	.ascii	"[ld-caribe] NEEDED DT_REL="
	.equ	needed_dt_rel_msg_len, . - needed_dt_rel_msg
needed_dt_relsz_msg:
	.ascii	"[ld-caribe] NEEDED DT_RELSZ="
	.equ	needed_dt_relsz_msg_len, . - needed_dt_relsz_msg
needed_dt_relent_msg:
	.ascii	"[ld-caribe] NEEDED DT_RELENT="
	.equ	needed_dt_relent_msg_len, . - needed_dt_relent_msg
needed_dt_jmprel_msg:
	.ascii	"[ld-caribe] NEEDED DT_JMPREL="
	.equ	needed_dt_jmprel_msg_len, . - needed_dt_jmprel_msg
needed_dt_pltrelsz_msg:
	.ascii	"[ld-caribe] NEEDED DT_PLTRELSZ="
	.equ	needed_dt_pltrelsz_msg_len, . - needed_dt_pltrelsz_msg
needed_dt_pltrel_msg:
	.ascii	"[ld-caribe] NEEDED DT_PLTREL="
	.equ	needed_dt_pltrel_msg_len, . - needed_dt_pltrel_msg
needed_dt_init_msg:
	.ascii	"[ld-caribe] NEEDED DT_INIT="
	.equ	needed_dt_init_msg_len, . - needed_dt_init_msg
needed_dt_init_array_msg:
	.ascii	"[ld-caribe] NEEDED DT_INIT_ARRAY="
	.equ	needed_dt_init_array_msg_len, . - needed_dt_init_array_msg
needed_dt_init_arraysz_msg:
	.ascii	"[ld-caribe] NEEDED DT_INIT_ARRAYSZ="
	.equ	needed_dt_init_arraysz_msg_len, . - needed_dt_init_arraysz_msg
needed_strtab_off_msg:
	.ascii	"[ld-caribe] NEEDED STRTAB off="
	.equ	needed_strtab_off_msg_len, . - needed_strtab_off_msg
needed_strtab_read_msg:
	.ascii	"[ld-caribe] NEEDED STRTAB read bytes="
	.equ	needed_strtab_read_msg_len, . - needed_strtab_read_msg
needed_soname_name_msg:
	.ascii	"[ld-caribe] NEEDED SONAME name="
	.equ	needed_soname_name_msg_len, . - needed_soname_name_msg
needed_symtab_off_msg:
	.ascii	"[ld-caribe] NEEDED SYMTAB off="
	.equ	needed_symtab_off_msg_len, . - needed_symtab_off_msg
needed_symtab_read_msg:
	.ascii	"[ld-caribe] NEEDED SYMTAB read bytes="
	.equ	needed_symtab_read_msg_len, . - needed_symtab_read_msg
needed_hash_nchain_msg:
	.ascii	"[ld-caribe] NEEDED HASH nchain="
	.equ	needed_hash_nchain_msg_len, . - needed_hash_nchain_msg
needed_gnuhash_nbucket_msg:
	.ascii	"[ld-caribe] NEEDED GNU_HASH nbucket="
	.equ	needed_gnuhash_nbucket_msg_len, . - needed_gnuhash_nbucket_msg
needed_gnuhash_symoffset_msg:
	.ascii	"[ld-caribe] NEEDED GNU_HASH symoffset="
	.equ	needed_gnuhash_symoffset_msg_len, . - needed_gnuhash_symoffset_msg
needed_gnuhash_bloom_size_msg:
	.ascii	"[ld-caribe] NEEDED GNU_HASH bloom_size="
	.equ	needed_gnuhash_bloom_size_msg_len, . - needed_gnuhash_bloom_size_msg
needed_gnuhash_bloom_shift_msg:
	.ascii	"[ld-caribe] NEEDED GNU_HASH bloom_shift="
	.equ	needed_gnuhash_bloom_shift_msg_len, . - needed_gnuhash_bloom_shift_msg
needed_gnuhash_bucket0_msg:
	.ascii	"[ld-caribe] NEEDED GNU_HASH bucket0="
	.equ	needed_gnuhash_bucket0_msg_len, . - needed_gnuhash_bucket0_msg
needed_versym_runtime_msg:
	.ascii	"[ld-caribe] NEEDED VERSYM runtime="
	.equ	needed_versym_runtime_msg_len, . - needed_versym_runtime_msg
needed_versym1_msg:
	.ascii	"[ld-caribe] NEEDED VERSYM[1]="
	.equ	needed_versym1_msg_len, . - needed_versym1_msg
needed_versym2_msg:
	.ascii	"[ld-caribe] NEEDED VERSYM[2]="
	.equ	needed_versym2_msg_len, . - needed_versym2_msg
needed_versym3_msg:
	.ascii	"[ld-caribe] NEEDED VERSYM[3]="
	.equ	needed_versym3_msg_len, . - needed_versym3_msg
needed_verdef_runtime_msg:
	.ascii	"[ld-caribe] NEEDED VERDEF runtime="
	.equ	needed_verdef_runtime_msg_len, . - needed_verdef_runtime_msg
needed_verdef_ndx_msg:
	.ascii	"[ld-caribe] NEEDED VERDEF ndx="
	.equ	needed_verdef_ndx_msg_len, . - needed_verdef_ndx_msg
needed_verdef_hash_msg:
	.ascii	"[ld-caribe] NEEDED VERDEF hash="
	.equ	needed_verdef_hash_msg_len, . - needed_verdef_hash_msg
needed_verdef_name_msg:
	.ascii	"[ld-caribe] NEEDED VERDEF name="
	.equ	needed_verdef_name_msg_len, . - needed_verdef_name_msg
needed_sym1_name_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] name="
	.equ	needed_sym1_name_msg_len, . - needed_sym1_name_msg
needed_sym1_value_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] value="
	.equ	needed_sym1_value_msg_len, . - needed_sym1_value_msg
needed_sym1_size_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] size="
	.equ	needed_sym1_size_msg_len, . - needed_sym1_size_msg
needed_sym1_file_off_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] file off="
	.equ	needed_sym1_file_off_msg_len, . - needed_sym1_file_off_msg
needed_sym1_data_read_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] data read bytes="
	.equ	needed_sym1_data_read_msg_len, . - needed_sym1_data_read_msg
needed_sym1_runtime_msg:
	.ascii	"[ld-caribe] NEEDED sym[1] runtime="
	.equ	needed_sym1_runtime_msg_len, . - needed_sym1_runtime_msg
needed_load_base_msg:
	.ascii	"[ld-caribe] NEEDED load base="
	.equ	needed_load_base_msg_len, . - needed_load_base_msg
needed_load_min_msg:
	.ascii	"[ld-caribe] NEEDED load min_vaddr="
	.equ	needed_load_min_msg_len, . - needed_load_min_msg
needed_load_span_msg:
	.ascii	"[ld-caribe] NEEDED load span="
	.equ	needed_load_span_msg_len, . - needed_load_span_msg
needed_load_bias_msg:
	.ascii	"[ld-caribe] NEEDED load bias="
	.equ	needed_load_bias_msg_len, . - needed_load_bias_msg
needed_load_seg_vaddr_msg:
	.ascii	"[ld-caribe] NEEDED LOAD vaddr="
	.equ	needed_load_seg_vaddr_msg_len, . - needed_load_seg_vaddr_msg
needed_load_seg_dst_msg:
	.ascii	"[ld-caribe] NEEDED LOAD dst="
	.equ	needed_load_seg_dst_msg_len, . - needed_load_seg_dst_msg
needed_load_seg_read_msg:
	.ascii	"[ld-caribe] NEEDED LOAD read bytes="
	.equ	needed_load_seg_read_msg_len, . - needed_load_seg_read_msg
needed_load_seg_map_msg:
	.ascii	"[ld-caribe] NEEDED LOAD mmap addr="
	.equ	needed_load_seg_map_msg_len, . - needed_load_seg_map_msg
needed_load_seg_mmap_ret_msg:
	.ascii	"[ld-caribe] NEEDED LOAD mmap ret="
	.equ	needed_load_seg_mmap_ret_msg_len, . - needed_load_seg_mmap_ret_msg
resolved_external_msg:
	.ascii	"[ld-caribe] resolved external name="
	.equ	resolved_external_msg_len, . - resolved_external_msg
gnu_hash_hit_msg:
	.ascii	"[ld-caribe] GNU_HASH hit name="
	.equ	gnu_hash_hit_msg_len, . - gnu_hash_hit_msg
gnu_hash_bloom_miss_msg:
	.ascii	"[ld-caribe] GNU_HASH bloom miss name="
	.equ	gnu_hash_bloom_miss_msg_len, . - gnu_hash_bloom_miss_msg
gnu_hash_hit_versym_msg:
	.ascii	"[ld-caribe] GNU_HASH hit versym="
	.equ	gnu_hash_hit_versym_msg_len, . - gnu_hash_hit_versym_msg
gnu_hash_versym_check_msg:
	.ascii	"[ld-caribe] GNU_HASH versym check="
	.equ	gnu_hash_versym_check_msg_len, . - gnu_hash_versym_check_msg
symtab_hit_versym_msg:
	.ascii	"[ld-caribe] SYMTAB hit versym="
	.equ	symtab_hit_versym_msg_len, . - symtab_hit_versym_msg
symtab_versym_check_msg:
	.ascii	"[ld-caribe] SYMTAB versym check="
	.equ	symtab_versym_check_msg_len, . - symtab_versym_check_msg
gnu_hash_missing_versym_check_msg:
	.ascii	"[ld-caribe] GNU_HASH missing VERSYM check="
	.equ	gnu_hash_missing_versym_check_msg_len, . - gnu_hash_missing_versym_check_msg
symtab_missing_versym_check_msg:
	.ascii	"[ld-caribe] SYMTAB missing VERSYM check="
	.equ	symtab_missing_versym_check_msg_len, . - symtab_missing_versym_check_msg
resolved_external_value_msg:
	.ascii	"[ld-caribe] resolved external value="
	.equ	resolved_external_value_msg_len, . - resolved_external_value_msg
weak_unresolved_msg:
	.ascii	"[ld-caribe] weak unresolved name="
	.equ	weak_unresolved_msg_len, . - weak_unresolved_msg
needed_ok_msg:
	.ascii	"[ld-caribe] NEEDED ELF probe ok\n"
	.equ	needed_ok_msg_len, . - needed_ok_msg
needed_path_prefix:
	.ascii	"/lib/"
	.equ	needed_path_prefix_len, . - needed_path_prefix
symrel_name_msg:
	.ascii	"[ld-caribe] symrel name="
	.equ	symrel_name_msg_len, . - symrel_name_msg
jmprel_name_msg:
	.ascii	"[ld-caribe] jmprel name="
	.equ	jmprel_name_msg_len, . - jmprel_name_msg
bad_symbol_name_msg:
	.ascii	"<bad-symbol-name>"
	.equ	bad_symbol_name_msg_len, . - bad_symbol_name_msg
bad_dynstr_msg:
	.ascii	"<bad-dynstr-offset>"
	.equ	bad_dynstr_msg_len, . - bad_dynstr_msg
dt_init_msg:
	.ascii	"[ld-caribe] DT_INIT main="
	.equ	dt_init_msg_len, . - dt_init_msg
dt_init_array_msg:
	.ascii	"[ld-caribe] DT_INIT_ARRAY main="
	.equ	dt_init_array_msg_len, . - dt_init_array_msg
dt_init_arraysz_msg:
	.ascii	"[ld-caribe] DT_INIT_ARRAYSZ main="
	.equ	dt_init_arraysz_msg_len, . - dt_init_arraysz_msg
reloc_msg:
	.ascii	"[ld-caribe] relocations applied="
	.equ	reloc_msg_len, . - reloc_msg
init_called_msg:
	.ascii	"[ld-caribe] DT_INIT called\n"
	.equ	init_called_msg_len, . - init_called_msg
init_array_called_msg:
	.ascii	"[ld-caribe] DT_INIT_ARRAY calls="
	.equ	init_array_called_msg_len, . - init_array_called_msg
needed_init_called_msg:
	.ascii	"[ld-caribe] NEEDED DT_INIT called index="
	.equ	needed_init_called_msg_len, . - needed_init_called_msg
needed_init_array_called_msg:
	.ascii	"[ld-caribe] NEEDED DT_INIT_ARRAY calls index="
	.equ	needed_init_array_called_msg_len, . - needed_init_array_called_msg
needed_reloc_msg:
	.ascii	"[ld-caribe] NEEDED relocations applied="
	.equ	needed_reloc_msg_len, . - needed_reloc_msg
done_msg:
	.ascii	"[ld-caribe] dynamic-loader handoff ok\n"
	.equ	done_msg_len, . - done_msg
jump_msg:
	.ascii	"[ld-caribe] jumping to main entry\n"
	.equ	jump_msg_len, . - jump_msg
newline:
	.ascii	"\n"
	.equ	newline_len, . - newline
hex_digits:
	.ascii	"0123456789abcdef"

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	mv	s2, sp
	li	s3, 0
	li	s4, 0
	li	s5, 0
	li	s6, 0
	li	s7, 0
	li	s8, 0
	li	s9, 0
	li	s10, 0
	li	s11, 0

	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	la	a1, argv0_msg
	li	a2, argv0_msg_len
	call	write_stdout
	lw	a1, 4(s2)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	lw	t0, 0(s2)
	addi	t1, s2, 4
	slli	t2, t0, 2
	add	t1, t1, t2
	addi	t1, t1, 4
1:
	lw	t2, 0(t1)
	addi	t1, t1, 4
	bnez	t2, 1b
2:
	lw	t2, 0(t1)
	lw	t3, 4(t1)
	li	t4, AT_NULL
	beq	t2, t4, 3f
	li	t4, AT_ENTRY
	bne	t2, t4, 4f
	mv	s3, t3
	j	5f
4:
	li	t4, AT_BASE
	bne	t2, t4, 6f
	mv	s4, t3
	j	5f
6:
	li	t4, AT_PHDR
	bne	t2, t4, 8f
	mv	s5, t3
	j	5f
8:
	li	t4, AT_PHENT
	bne	t2, t4, 9f
	mv	s6, t3
	j	5f
9:
	li	t4, AT_PHNUM
	bne	t2, t4, 5f
	mv	s7, t3
5:
	addi	t1, t1, 8
	j	2b
3:
	la	a1, entry_msg
	li	a2, entry_msg_len
	call	write_stdout
	mv	a0, s3
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, base_msg
	li	a2, base_msg_len
	call	write_stdout
	mv	a0, s4
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, phdr_msg
	li	a2, phdr_msg_len
	call	write_stdout
	mv	a0, s5
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	call	scan_main_dynamic
	la	a1, dynamic_msg
	li	a2, dynamic_msg_len
	call	write_stdout
	beqz	s8, 10f
	mv	a0, s8
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	11f
10:
	la	a1, dynamic_absent_msg
	li	a2, dynamic_absent_msg_len
	call	write_stdout
11:
	la	a1, load_bias_msg
	li	a2, load_bias_msg_len
	call	write_stdout
	la	t0, main_bias_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	parse_dynamic_tags
	la	a1, dt_rel_msg
	li	a2, dt_rel_msg_len
	call	write_stdout
	mv	a0, s9
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_relsz_msg
	li	a2, dt_relsz_msg_len
	call	write_stdout
	mv	a0, s10
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_relent_msg
	li	a2, dt_relent_msg_len
	call	write_stdout
	mv	a0, s11
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_jmprel_msg
	li	a2, dt_jmprel_msg_len
	call	write_stdout
	la	t0, dyn_jmprel_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_pltrelsz_msg
	li	a2, dt_pltrelsz_msg_len
	call	write_stdout
	la	t0, dyn_pltrelsz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_pltrel_msg
	li	a2, dt_pltrel_msg_len
	call	write_stdout
	la	t0, dyn_pltrel_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_init_array_msg
	li	a2, dt_init_array_msg_len
	call	write_stdout
	la	t0, dyn_init_array_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_init_arraysz_msg
	li	a2, dt_init_arraysz_msg_len
	call	write_stdout
	la	t0, dyn_init_arraysz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_symtab_msg
	li	a2, dt_symtab_msg_len
	call	write_stdout
	la	t0, dyn_symtab_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_strtab_msg
	li	a2, dt_strtab_msg_len
	call	write_stdout
	la	t0, dyn_strtab_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_strsz_msg
	li	a2, dt_strsz_msg_len
	call	write_stdout
	la	t0, dyn_strsz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_syment_msg
	li	a2, dt_syment_msg_len
	call	write_stdout
	la	t0, dyn_syment_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_versym_msg
	li	a2, dt_versym_msg_len
	call	write_stdout
	la	t0, dyn_versym_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	read_main_versym
	la	a1, dt_needed_msg
	li	a2, dt_needed_msg_len
	call	write_stdout
	la	t0, dyn_needed_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, dyn_needed_slot
	lw	a0, 0(t0)
	la	a1, needed_name_msg
	li	a2, needed_name_msg_len
	call	log_dynstr_offset
	la	a1, dt_needed_count_msg
	li	a2, dt_needed_count_msg_len
	call	write_stdout
	la	t0, dyn_needed_count_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	probe_needed_libraries
	la	a1, dt_soname_msg
	li	a2, dt_soname_msg_len
	call	write_stdout
	la	t0, dyn_soname_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, dyn_soname_slot
	lw	a0, 0(t0)
	la	a1, soname_name_msg
	li	a2, soname_name_msg_len
	call	log_dynstr_offset
	la	a1, dt_verneed_msg
	li	a2, dt_verneed_msg_len
	call	write_stdout
	la	t0, dyn_verneed_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, dt_verneednum_msg
	li	a2, dt_verneednum_msg_len
	call	write_stdout
	la	t0, dyn_verneednum_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	read_main_verneed
	la	a1, dt_init_msg
	li	a2, dt_init_msg_len
	call	write_stdout
	la	t0, dyn_init_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	apply_main_rel
	call	apply_main_jmprel
	la	a1, reloc_msg
	li	a2, reloc_msg_len
	call	write_stdout
	mv	a0, s0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	call_needed_initializers
	call	call_main_init
	call	call_main_init_array

	la	a1, done_msg
	li	a2, 38
	call	write_stdout

	la	a1, jump_msg
	li	a2, jump_msg_len
	call	write_stdout

	mv	sp, s2
	jr	s3
7:
	j	7b

scan_main_dynamic:
	beqz	s5, 6f
	beqz	s6, 6f
	beqz	s7, 6f
	mv	t0, s5
	mv	t1, s7
	mv	t2, s6
	li	t3, PT_PHDR
1:
	beqz	t1, 2f
	lw	t4, 0(t0)
	bne	t4, t3, 3f
	lw	t5, 8(t0)
	sub	t6, s5, t5
	la	t4, main_bias_slot
	sw	t6, 0(t4)
	j	2f
3:
	add	t0, t0, t2
	addi	t1, t1, -1
	j	1b
2:
	mv	t0, s5
	mv	t1, s7
	mv	t2, s6
	la	t6, main_bias_slot
	lw	t6, 0(t6)
	li	t3, PT_DYNAMIC
4:
	beqz	t1, 6f
	lw	t4, 0(t0)
	bne	t4, t3, 5f
	lw	t5, 8(t0)
	add	s8, t5, t6
	ret
5:
	add	t0, t0, t2
	addi	t1, t1, -1
	j	4b
6:
	ret

parse_dynamic_tags:
	beqz	s8, 4f
	la	t0, dyn_needed_slot
	sw	zero, 0(t0)
	la	t0, dyn_needed_count_slot
	sw	zero, 0(t0)
	la	t0, dyn_verneed_slot
	sw	zero, 0(t0)
	la	t0, dyn_verneednum_slot
	sw	zero, 0(t0)
	la	t0, dyn_versym_slot
	sw	zero, 0(t0)
	la	t0, needed_obj_count_slot
	sw	zero, 0(t0)
	mv	t0, s8
	li	t1, 64
	la	t6, main_bias_slot
	lw	t6, 0(t6)
1:
	beqz	t1, 4f
	lw	t2, 0(t0)
	lw	t3, 4(t0)
	li	t4, DT_NULL
	beq	t2, t4, 4f
	li	t4, DT_STRTAB
	bne	t2, t4, 6f
	add	t3, t3, t6
	la	t5, dyn_strtab_slot
	sw	t3, 0(t5)
	j	3f
6:
	li	t4, DT_SYMTAB
	bne	t2, t4, 7f
	add	t3, t3, t6
	la	t5, dyn_symtab_slot
	sw	t3, 0(t5)
	j	3f
7:
	li	t4, DT_STRSZ
	bne	t2, t4, 15f
	la	t5, dyn_strsz_slot
	sw	t3, 0(t5)
	j	3f
15:
	li	t4, DT_SYMENT
	bne	t2, t4, 8f
	la	t5, dyn_syment_slot
	sw	t3, 0(t5)
	j	3f
8:
	li	t4, DT_NEEDED
	bne	t2, t4, 16f
	la	t4, dyn_needed_count_slot
	lw	t5, 0(t4)
	bnez	t5, 18f
	la	t4, dyn_needed_slot
	sw	t3, 0(t4)
18:
	li	t2, MAX_NEEDED_OBJECTS
	bgeu	t5, t2, 3f
	la	t2, dyn_needed_offsets_buf
	slli	t5, t5, 2
	add	t2, t2, t5
	sw	t3, 0(t2)
	la	t2, dyn_needed_count_slot
	lw	t5, 0(t2)
	addi	t5, t5, 1
	sw	t5, 0(t2)
	j	3f
16:
	li	t4, DT_SONAME
	bne	t2, t4, 17f
	la	t5, dyn_soname_slot
	sw	t3, 0(t5)
	j	3f
17:
	li	t4, DT_INIT
	bne	t2, t4, 9f
	add	t3, t3, t6
	la	t5, dyn_init_slot
	sw	t3, 0(t5)
	j	3f
9:
	li	t4, DT_INIT_ARRAY
	bne	t2, t4, 10f
	add	t3, t3, t6
	la	t5, dyn_init_array_slot
	sw	t3, 0(t5)
	j	3f
10:
	li	t4, DT_INIT_ARRAYSZ
	bne	t2, t4, 11f
	la	t5, dyn_init_arraysz_slot
	sw	t3, 0(t5)
	j	3f
11:
	li	t4, DT_JMPREL
	bne	t2, t4, 12f
	add	t3, t3, t6
	la	t5, dyn_jmprel_slot
	sw	t3, 0(t5)
	j	3f
12:
	li	t4, DT_PLTRELSZ
	bne	t2, t4, 13f
	la	t5, dyn_pltrelsz_slot
	sw	t3, 0(t5)
	j	3f
13:
	li	t4, DT_PLTREL
	bne	t2, t4, 14f
	la	t5, dyn_pltrel_slot
	sw	t3, 0(t5)
	j	3f
14:
	li	t4, DT_REL
	bne	t2, t4, 2f
	add	t3, t3, t6
	mv	s9, t3
	j	3f
2:
	li	t4, DT_RELSZ
	bne	t2, t4, 5f
	mv	s10, t3
	j	3f
5:
	li	t4, DT_RELENT
	bne	t2, t4, 19f
	mv	s11, t3
	j	3f
19:
	li	t4, DT_VERNEED
	bne	t2, t4, 20f
	add	t3, t3, t6
	la	t5, dyn_verneed_slot
	sw	t3, 0(t5)
	j	3f
20:
	li	t4, DT_VERNEEDNUM
	bne	t2, t4, 21f
	la	t5, dyn_verneednum_slot
	sw	t3, 0(t5)
	j	3f
21:
	li	t4, DT_VERSYM
	bne	t2, t4, 3f
	add	t3, t3, t6
	la	t5, dyn_versym_slot
	sw	t3, 0(t5)
3:
	addi	t0, t0, 8
	addi	t1, t1, -1
	j	1b
4:
	ret

read_main_versym:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, dyn_versym_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	a1, main_versym6_msg
	li	a2, main_versym6_msg_len
	call	write_stdout
	la	t0, dyn_versym_slot
	lw	t1, 0(t0)
	lhu	a0, 12(t1)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, main_versym7_msg
	li	a2, main_versym7_msg_len
	call	write_stdout
	la	t0, dyn_versym_slot
	lw	t1, 0(t0)
	lhu	a0, 14(t1)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, main_versym8_msg
	li	a2, main_versym8_msg_len
	call	write_stdout
	la	t0, dyn_versym_slot
	lw	t1, 0(t0)
	lhu	a0, 16(t1)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_main_verneed:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, dyn_verneed_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, dyn_verneednum_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	la	t0, dyn_strtab_slot
	lw	t3, 0(t0)
	beqz	t3, 9f
	la	t0, dyn_strsz_slot
	lw	t4, 0(t0)
	beqz	t4, 9f
	sw	t1, 8(sp)
	lw	t2, 4(t1)
	bgeu	t2, t4, 1f
	la	t0, main_verneed_file_off_slot
	sw	t2, 0(t0)
	la	a1, main_verneed_file_msg
	li	a2, main_verneed_file_msg_len
	call	write_stdout
	la	t0, dyn_strtab_slot
	lw	a1, 0(t0)
	lw	t1, 8(sp)
	lw	t2, 4(t1)
	add	a1, a1, t2
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
1:
	lw	t1, 8(sp)
	lw	t2, 8(t1)
	beqz	t2, 9f
	add	t1, t1, t2
	lw	t2, 0(t1)
	la	t0, main_verneed_hash_slot
	sw	t2, 0(t0)
	sw	t2, 4(sp)
	la	a1, main_verneed_hash_msg
	li	a2, main_verneed_hash_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t2, 8(t1)
	add	t1, t1, t2
	lhu	t2, 6(t1)
	la	t0, main_verneed_other_slot
	sw	t2, 0(t0)
	sw	t2, 4(sp)
	la	a1, main_verneed_other_msg
	li	a2, main_verneed_other_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t2, 8(t1)
	add	t1, t1, t2
	lw	t2, 8(t1)
	la	t0, dyn_strsz_slot
	lw	t4, 0(t0)
	bgeu	t2, t4, 9f
	la	t0, main_verneed_name_off_slot
	sw	t2, 0(t0)
	la	a1, main_verneed_name_msg
	li	a2, main_verneed_name_msg_len
	call	write_stdout
	la	t0, dyn_strtab_slot
	lw	a1, 0(t0)
	add	a1, a1, t2
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	verify_main_verneed
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

verify_main_verneed:
	addi	sp, sp, -48
	sw	ra, 44(sp)
	la	t0, main_verneed_hash_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	sw	t1, 40(sp)
	la	t0, main_verneed_other_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	sw	t2, 36(sp)
	la	t0, dyn_strtab_slot
	lw	t3, 0(t0)
	beqz	t3, 9f
	la	t0, main_verneed_file_off_slot
	lw	t4, 0(t0)
	add	t5, t3, t4
	sw	t5, 32(sp)
	la	t0, main_verneed_name_off_slot
	lw	t4, 0(t0)
	add	t5, t3, t4
	sw	t5, 20(sp)
	la	t0, needed_obj_count_slot
	lw	t5, 0(t0)
	beqz	t5, 8f
	sw	t5, 28(sp)
	sw	zero, 24(sp)
1:
	lw	t0, 24(sp)
	lw	t1, 28(sp)
	bgeu	t0, t1, 8f
	la	t2, needed_obj_name_pool
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t0, t3
	add	a1, t2, t4
	lw	a0, 32(sp)
	call	cstr_equal
	bnez	a0, 2f
	lw	t0, 24(sp)
	addi	t0, t0, 1
	sw	t0, 24(sp)
	j	1b
2:
	lw	t0, 24(sp)
	slli	t1, t0, 2
	la	t2, needed_obj_verdef_hash_buf
	add	t2, t2, t1
	lw	t3, 0(t2)
	lw	t4, 40(sp)
	bne	t3, t4, 8f
	la	t2, needed_obj_verdef_ndx_buf
	add	t2, t2, t1
	lw	t3, 0(t2)
	lw	t4, 36(sp)
	bne	t3, t4, 8f
	la	t2, needed_obj_verdef_name_off_buf
	add	t2, t2, t1
	lw	t3, 0(t2)
	beqz	t3, 7f
	la	t2, needed_obj_strtab_read_buf
	add	t2, t2, t1
	lw	t4, 0(t2)
	bgeu	t3, t4, 7f
	la	a1, needed_obj_strtab_pool
	li	t4, NEEDED_OBJ_STRTAB_BYTES
	lw	t0, 24(sp)
	mul	t5, t0, t4
	add	a1, a1, t5
	add	a1, a1, t3
	lw	a0, 20(sp)
	call	cstr_equal
	beqz	a0, 7f
	la	a1, main_verneed_name_match_msg
	li	a2, main_verneed_name_match_msg_len
	call	write_stdout
	li	a0, 1
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	li	t0, 1
	la	t1, main_verneed_match_slot
	sw	t0, 0(t1)
	la	a1, main_verneed_match_msg
	li	a2, main_verneed_match_msg_len
	call	write_stdout
	li	a0, 1
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
7:
	la	a1, main_verneed_name_match_msg
	li	a2, main_verneed_name_match_msg_len
	call	write_stdout
	li	a0, 0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	8f
8:
	la	a1, main_verneed_match_msg
	li	a2, main_verneed_match_msg_len
	call	write_stdout
	li	a0, 0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	li	a0, 127
	li	a7, SYS_EXIT_GROUP
	ecall
	j	8b
9:
	lw	ra, 44(sp)
	addi	sp, sp, 48
	ret

enforce_gnuhash_versym:
	la	a2, gnu_hash_versym_check_msg
	li	a3, gnu_hash_versym_check_msg_len
	j	enforce_needed_versym_with_msg

enforce_symtab_versym:
	la	a2, symtab_versym_check_msg
	li	a3, symtab_versym_check_msg_len
	j	enforce_needed_versym_with_msg

enforce_needed_versym_with_msg:
	addi	sp, sp, -40
	sw	ra, 36(sp)
	sw	a0, 32(sp)
	sw	a1, 28(sp)
	sw	a2, 24(sp)
	sw	a3, 20(sp)
	la	t0, main_verneed_match_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, current_main_sym_versym_slot
	lw	t1, 0(t0)
	bnez	t1, 1f
	la	t0, main_verneed_other_slot
	lw	t1, 0(t0)
1:
	beqz	t1, 9f
	sw	t1, 16(sp)
	la	t0, dyn_strtab_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	la	t0, main_verneed_file_off_slot
	lw	t3, 0(t0)
	add	t2, t2, t3
	sw	t2, 12(sp)
	lw	t0, 32(sp)
	la	t1, needed_obj_count_slot
	lw	t1, 0(t1)
	bgeu	t0, t1, 9f
	la	t2, needed_obj_name_pool
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t0, t3
	add	a1, t2, t4
	lw	a0, 12(sp)
	call	cstr_equal
	beqz	a0, 9f
	lw	t0, 28(sp)
	li	t1, 0x7fff
	and	t0, t0, t1
	lw	t1, 16(sp)
	bne	t0, t1, 8f
	lw	a1, 24(sp)
	lw	a2, 20(sp)
	call	write_stdout
	li	a0, 1
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
8:
	lw	a1, 24(sp)
	lw	a2, 20(sp)
	call	write_stdout
	li	a0, 0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	li	a0, 127
	li	a7, SYS_EXIT_GROUP
	ecall
	j	8b
9:
	lw	ra, 36(sp)
	addi	sp, sp, 40
	ret

enforce_missing_needed_versym_with_msg:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	sw	a0, 24(sp)
	sw	a1, 20(sp)
	sw	a2, 16(sp)
	la	t0, main_verneed_match_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, current_main_sym_versym_slot
	lw	t1, 0(t0)
	li	t2, 1
	bleu	t1, t2, 9f
	la	t0, dyn_strtab_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	la	t0, main_verneed_file_off_slot
	lw	t3, 0(t0)
	add	t2, t2, t3
	sw	t2, 12(sp)
	lw	t0, 24(sp)
	la	t1, needed_obj_count_slot
	lw	t1, 0(t1)
	bgeu	t0, t1, 9f
	la	t2, needed_obj_name_pool
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t0, t3
	add	a1, t2, t4
	lw	a0, 12(sp)
	call	cstr_equal
	beqz	a0, 9f
	lw	a1, 20(sp)
	lw	a2, 16(sp)
	call	write_stdout
	li	a0, 0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	li	a0, 127
	li	a7, SYS_EXIT_GROUP
	ecall
	j	8f
8:
	j	8b
9:
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

apply_main_rel:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	li	s0, 0
	beqz	s9, 4f
	beqz	s10, 4f
	beqz	s11, 4f
	li	t0, 8
	bne	s11, t0, 4f
	mv	t1, s10
	divu	t1, t1, s11
	mv	t2, s9
1:
	beqz	t1, 4f
	lw	t4, 0(t2)
	la	t0, main_bias_slot
	lw	t0, 0(t0)
	add	t4, t4, t0
	lw	t5, 4(t2)
	andi	t6, t5, 0xff
	li	t3, R_RISCV_RELATIVE
	beq	t6, t3, 5f
	li	t3, R_RISCV_32
	beq	t6, t3, 6f
	li	t3, R_RISCV_JUMP_SLOT
	beq	t6, t3, 7f
	j	3f
5:
	lw	t6, 0(t4)
	add	t6, t6, t0
	sw	t6, 0(t4)
	addi	s0, s0, 1
	j	3f
6:
	srli	t5, t5, 8
	la	t0, dyn_symtab_slot
	lw	t0, 0(t0)
	beqz	t0, 3f
	la	t3, dyn_syment_slot
	lw	t3, 0(t3)
	beqz	t3, 3f
	mul	t5, t5, t3
	add	t0, t0, t5
	mv	a0, t0
	la	a1, symrel_name_msg
	li	a2, symrel_name_msg_len
	call	log_symbol_name_preserve
	lw	t6, 4(t0)
	bnez	t6, 8f
	mv	a0, t0
	call	resolve_needed_symbol_preserve
	la	t3, resolved_symbol_found_slot
	lw	t3, 0(t3)
	beqz	t3, 8f
	la	t3, resolved_symbol_value_slot
	lw	t6, 0(t3)
	lw	t5, 0(t4)
	add	t6, t6, t5
	sw	t6, 0(t4)
	addi	s0, s0, 1
	j	3f
8:
	la	t3, main_bias_slot
	lw	t3, 0(t3)
	add	t6, t6, t3
	lw	t5, 0(t4)
	add	t6, t6, t5
	sw	t6, 0(t4)
	addi	s0, s0, 1
	j	3f
7:
	srli	t5, t5, 8
	la	t0, dyn_symtab_slot
	lw	t0, 0(t0)
	beqz	t0, 3f
	la	t3, dyn_syment_slot
	lw	t3, 0(t3)
	beqz	t3, 3f
	mul	t5, t5, t3
	add	t0, t0, t5
	mv	a0, t0
	la	a1, jmprel_name_msg
	li	a2, jmprel_name_msg_len
	call	log_symbol_name_preserve
	lw	t6, 4(t0)
	bnez	t6, 8f
	mv	a0, t0
	call	resolve_needed_symbol_preserve
	la	t3, resolved_symbol_found_slot
	lw	t3, 0(t3)
	beqz	t3, 3f
	la	t3, resolved_symbol_value_slot
	lw	t6, 0(t3)
	sw	t6, 0(t4)
	addi	s0, s0, 1
	j	3f
8:
	la	t3, main_bias_slot
	lw	t3, 0(t3)
	add	t6, t6, t3
	sw	t6, 0(t4)
	addi	s0, s0, 1
3:
	add	t2, t2, s11
	addi	t1, t1, -1
	j	1b
4:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

apply_main_jmprel:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, dyn_jmprel_slot
	lw	t2, 0(t0)
	la	t0, dyn_pltrelsz_slot
	lw	t1, 0(t0)
	la	t0, dyn_pltrel_slot
	lw	t0, 0(t0)
	beqz	t2, 4f
	beqz	t1, 4f
	li	t3, DT_REL
	bne	t0, t3, 4f
	li	t0, 8
	divu	t1, t1, t0
1:
	beqz	t1, 4f
	lw	t4, 0(t2)
	la	t0, main_bias_slot
	lw	t0, 0(t0)
	add	t4, t4, t0
	lw	t5, 4(t2)
	andi	t6, t5, 0xff
	li	t3, R_RISCV_JUMP_SLOT
	bne	t6, t3, 3f
	srli	t5, t5, 8
	la	t0, dyn_symtab_slot
	lw	t0, 0(t0)
	beqz	t0, 3f
	la	t3, dyn_syment_slot
	lw	t3, 0(t3)
	beqz	t3, 3f
	mul	t5, t5, t3
	add	t0, t0, t5
	mv	a0, t0
	la	a1, jmprel_name_msg
	li	a2, jmprel_name_msg_len
	call	log_symbol_name_preserve
	lw	t6, 4(t0)
	bnez	t6, 5f
	mv	a0, t0
	call	resolve_needed_symbol_preserve
	la	t3, resolved_symbol_found_slot
	lw	t3, 0(t3)
	beqz	t3, 3f
	la	t3, resolved_symbol_value_slot
	lw	t6, 0(t3)
	sw	t6, 0(t4)
	addi	s0, s0, 1
	j	3f
5:
	la	t3, main_bias_slot
	lw	t3, 0(t3)
	add	t6, t6, t3
	sw	t6, 0(t4)
	addi	s0, s0, 1
3:
	addi	t2, t2, 8
	addi	t1, t1, -1
	j	1b
4:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

log_symbol_name_preserve:
	addi	sp, sp, -80
	sw	ra, 76(sp)
	sw	t0, 72(sp)
	sw	t1, 68(sp)
	sw	t2, 64(sp)
	sw	t3, 60(sp)
	sw	t4, 56(sp)
	sw	t5, 52(sp)
	sw	t6, 48(sp)
	sw	a0, 44(sp)
	sw	a1, 40(sp)
	sw	a2, 36(sp)
	lw	a1, 40(sp)
	lw	a2, 36(sp)
	call	write_stdout
	lw	t0, 44(sp)
	lw	t1, 0(t0)
	la	t2, dyn_strtab_slot
	lw	t2, 0(t2)
	beqz	t2, 1f
	la	t3, dyn_strsz_slot
	lw	t3, 0(t3)
	beqz	t3, 2f
	bgeu	t1, t3, 1f
2:
	add	a1, t2, t1
	call	write_cstr_stdout
	j	3f
1:
	la	a1, bad_symbol_name_msg
	li	a2, bad_symbol_name_msg_len
	call	write_stdout
3:
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	ra, 76(sp)
	lw	t0, 72(sp)
	lw	t1, 68(sp)
	lw	t2, 64(sp)
	lw	t3, 60(sp)
	lw	t4, 56(sp)
	lw	t5, 52(sp)
	lw	t6, 48(sp)
	addi	sp, sp, 80
	ret

resolve_needed_symbol_preserve:
	addi	sp, sp, -96
	sw	ra, 92(sp)
	sw	t0, 88(sp)
	sw	t1, 84(sp)
	sw	t2, 80(sp)
	sw	t3, 76(sp)
	sw	t4, 72(sp)
	sw	t5, 68(sp)
	sw	t6, 64(sp)
	sw	a0, 60(sp)
	la	t0, resolved_symbol_found_slot
	sw	zero, 0(t0)
	la	t0, resolved_symbol_value_slot
	sw	zero, 0(t0)
	la	t0, current_main_sym_versym_slot
	sw	zero, 0(t0)
	lw	t0, 60(sp)
	la	t1, dyn_symtab_slot
	lw	t1, 0(t1)
	beqz	t1, 12f
	la	t2, dyn_syment_slot
	lw	t2, 0(t2)
	beqz	t2, 12f
	la	t3, dyn_versym_slot
	lw	t3, 0(t3)
	beqz	t3, 12f
	bltu	t0, t1, 12f
	sub	t4, t0, t1
	divu	t4, t4, t2
	slli	t5, t4, 1
	add	t3, t3, t5
	lhu	t6, 0(t3)
	la	t3, current_main_sym_versym_slot
	sw	t6, 0(t3)
	li	t5, 1
	bleu	t6, t5, 12f
	sw	t6, 56(sp)
	la	a1, main_sym_versym_msg
	li	a2, main_sym_versym_msg_len
	call	write_stdout
	lw	a0, 56(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
12:
	lw	t0, 60(sp)
	lw	t2, 0(t0)
	la	t3, dyn_strtab_slot
	lw	t3, 0(t3)
	beqz	t3, 9f
	la	t4, dyn_strsz_slot
	lw	t4, 0(t4)
	beqz	t4, 9f
	bgeu	t2, t4, 9f
	add	t2, t2, t3
	sw	t2, 56(sp)
	mv	a0, t2
	call	resolve_needed_symbol_table
	la	t0, resolved_symbol_found_slot
	lw	t0, 0(t0)
	bnez	t0, 9f
	la	t0, needed_symtab_read_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_lib_syment_slot
	lw	t3, 0(t0)
	li	t4, 16
	bltu	t3, t4, 9f
	divu	t1, t1, t3
	li	t4, 1
	bgeu	t4, t1, 9f
	la	t0, needed_symtab_buf
	add	t0, t0, t3
	addi	t1, t1, -1
	sw	t0, 52(sp)
	sw	t1, 48(sp)
	sw	t3, 44(sp)
1:
	lw	t1, 48(sp)
	beqz	t1, 9f
	lw	t0, 52(sp)
	lw	t2, 0(t0)
	la	t3, needed_strtab_read_slot
	lw	t3, 0(t3)
	bgeu	t2, t3, 5f
	la	t4, needed_strtab_buf
	add	t4, t4, t2
	lw	t2, 56(sp)
2:
	lbu	t5, 0(t2)
	lbu	t6, 0(t4)
	bne	t5, t6, 5f
	beqz	t5, 3f
	addi	t2, t2, 1
	addi	t4, t4, 1
	j	2b
3:
	lw	t0, 52(sp)
	lbu	t5, 12(t0)
	srli	t6, t5, 4
	li	t3, 1
	beq	t6, t3, 10f
	li	t3, 2
	beq	t6, t3, 10f
	j	5f
10:
	andi	t6, t5, 0x0f
	li	t3, 2
	bleu	t6, t3, 11f
	j	5f
11:
	lw	t2, 4(t0)
	beqz	t2, 5f
	la	t3, needed_load_base_slot
	lw	t3, 0(t3)
	beqz	t3, 7f
	la	t3, needed_load_bias_slot
	lw	t3, 0(t3)
	add	t0, t2, t3
	j	4f
7:
	la	t3, needed_sym1_value_slot
	lw	t3, 0(t3)
	bne	t2, t3, 5f
	la	t3, needed_sym1_runtime_addr_slot
	lw	t0, 0(t3)
	beqz	t0, 5f
4:
	la	t1, resolved_symbol_value_slot
	sw	t0, 0(t1)
	li	t0, 1
	la	t1, resolved_symbol_found_slot
	sw	t0, 0(t1)
	la	a1, resolved_external_msg
	li	a2, resolved_external_msg_len
	call	write_stdout
	lw	t0, 60(sp)
	lw	t0, 0(t0)
	la	t1, dyn_strtab_slot
	lw	t1, 0(t1)
	add	a1, t1, t0
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, resolved_external_value_msg
	li	a2, resolved_external_value_msg_len
	call	write_stdout
	la	t0, resolved_symbol_value_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
5:
	lw	t0, 52(sp)
	lw	t3, 44(sp)
	add	t0, t0, t3
	sw	t0, 52(sp)
	lw	t1, 48(sp)
	addi	t1, t1, -1
	sw	t1, 48(sp)
	j	1b
9:
	lw	ra, 92(sp)
	lw	t0, 88(sp)
	lw	t1, 84(sp)
	lw	t2, 80(sp)
	lw	t3, 76(sp)
	lw	t4, 72(sp)
	lw	t5, 68(sp)
	lw	t6, 64(sp)
	addi	sp, sp, 96
	ret

log_dynstr_offset:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	sw	a0, 24(sp)
	sw	a1, 20(sp)
	sw	a2, 16(sp)
	lw	a1, 20(sp)
	lw	a2, 16(sp)
	call	write_stdout
	lw	t0, 24(sp)
	la	t1, dyn_strtab_slot
	lw	t1, 0(t1)
	beqz	t1, 1f
	la	t2, dyn_strsz_slot
	lw	t2, 0(t2)
	beqz	t2, 2f
	bgeu	t0, t2, 1f
2:
	add	a1, t1, t0
	call	write_cstr_stdout
	j	3f
1:
	la	a1, bad_dynstr_msg
	li	a2, bad_dynstr_msg_len
	call	write_stdout
3:
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

gnu_hash_name:
	li	t0, 5381
1:
	lbu	t1, 0(a0)
	beqz	t1, 2f
	slli	t2, t0, 5
	add	t0, t2, t0
	add	t0, t0, t1
	addi	a0, a0, 1
	j	1b
2:
	mv	a0, t0
	ret

cstr_equal:
1:
	lbu	t0, 0(a0)
	lbu	t1, 0(a1)
	bne	t0, t1, 2f
	beqz	t0, 3f
	addi	a0, a0, 1
	addi	a1, a1, 1
	j	1b
2:
	li	a0, 0
	ret
3:
	li	a0, 1
	ret

resolve_needed_symbol_gnuhash:
	addi	sp, sp, -96
	sw	ra, 92(sp)
	sw	a0, 88(sp)
	sw	a1, 84(sp)
	sw	a2, 80(sp)
	sw	a3, 76(sp)
	sw	a4, 72(sp)
	sw	a5, 68(sp)
	sw	a6, 64(sp)
	sw	a7, 60(sp)
	beqz	a7, 9f
	lw	t0, 0(a7)
	beqz	t0, 9f
	sw	t0, 56(sp)
	lw	t0, 4(a7)
	sw	t0, 52(sp)
	lw	t0, 8(a7)
	beqz	t0, 9f
	sw	t0, 48(sp)
	lw	t0, 12(a7)
	sw	t0, 44(sp)
	lw	t0, 84(sp)
	srli	t1, t0, 5
	lw	t2, 48(sp)
	remu	t1, t1, t2
	slli	t1, t1, 2
	lw	t2, 60(sp)
	addi	t2, t2, 16
	add	t2, t2, t1
	lw	t2, 0(t2)
	li	t3, 1
	andi	t4, t0, 31
	sll	t3, t3, t4
	lw	t4, 44(sp)
	srl	t4, t0, t4
	andi	t4, t4, 31
	li	t5, 1
	sll	t5, t5, t4
	or	t3, t3, t5
	and	t2, t2, t3
	beq	t2, t3, 2f
	la	a1, gnu_hash_bloom_miss_msg
	li	a2, gnu_hash_bloom_miss_msg_len
	call	write_stdout
	lw	a1, 88(sp)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
2:
	lw	t0, 60(sp)
	lw	t1, 48(sp)
	slli	t1, t1, 2
	addi	t0, t0, 16
	add	t0, t0, t1
	sw	t0, 40(sp)
	lw	t1, 84(sp)
	lw	t2, 56(sp)
	remu	t1, t1, t2
	slli	t1, t1, 2
	add	t1, t0, t1
	lw	t1, 0(t1)
	lw	t2, 52(sp)
	bltu	t1, t2, 9f
	lw	t2, 72(sp)
	bgeu	t1, t2, 9f
	sw	t1, 36(sp)
	lw	t2, 56(sp)
	slli	t2, t2, 2
	add	t0, t0, t2
	sw	t0, 32(sp)
	lw	t2, 52(sp)
	sub	t1, t1, t2
	slli	t1, t1, 2
	add	t1, t0, t1
	sw	t1, 28(sp)
	la	t0, needed_obj_symtab_pool
	li	t1, NEEDED_OBJ_SYMTAB_BYTES
	lw	t2, 80(sp)
	mul	t1, t2, t1
	add	t0, t0, t1
	sw	t0, 24(sp)
	la	t0, needed_obj_strtab_pool
	li	t1, NEEDED_OBJ_STRTAB_BYTES
	lw	t2, 80(sp)
	mul	t1, t2, t1
	add	t0, t0, t1
	sw	t0, 20(sp)
1:
	lw	t4, 36(sp)
	lw	t5, 72(sp)
	bgeu	t4, t5, 9f
	lw	t0, 28(sp)
	lw	t1, 0(t0)
	sw	t1, 12(sp)
	lw	t2, 84(sp)
	xor	t3, t1, t2
	srli	t3, t3, 1
	bnez	t3, 7f
	lw	t0, 24(sp)
	lw	t2, 76(sp)
	mul	t3, t4, t2
	add	t0, t0, t3
	lw	t2, 0(t0)
	lw	t3, 68(sp)
	bgeu	t2, t3, 7f
	lw	t3, 20(sp)
	add	t3, t3, t2
	sw	t0, 16(sp)
	lw	a0, 88(sp)
	mv	a1, t3
	call	cstr_equal
	beqz	a0, 7f
	lw	t0, 16(sp)
	lbu	t5, 12(t0)
	srli	t6, t5, 4
	li	t3, 1
	beq	t6, t3, 2f
	li	t3, 2
	beq	t6, t3, 2f
	j	7f
2:
	andi	t6, t5, 0x0f
	li	t3, 2
	bleu	t6, t3, 3f
	j	7f
3:
	lw	t2, 4(t0)
	beqz	t2, 7f
	lw	t3, 64(sp)
	add	t2, t2, t3
	la	t0, resolved_symbol_value_slot
	sw	t2, 0(t0)
	li	t2, 1
	la	t0, resolved_symbol_found_slot
	sw	t2, 0(t0)
	la	a1, gnu_hash_hit_msg
	li	a2, gnu_hash_hit_msg_len
	call	write_stdout
	lw	a1, 88(sp)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_obj_versym_buf
	lw	t1, 80(sp)
	slli	t1, t1, 2
	add	t0, t0, t1
	lw	t0, 0(t0)
	bnez	t0, .Lgnu_hash_have_versym
	lw	a0, 80(sp)
	la	a1, gnu_hash_missing_versym_check_msg
	li	a2, 42
	call	enforce_missing_needed_versym_with_msg
	j	4f
.Lgnu_hash_have_versym:
	lw	t1, 36(sp)
	slli	t1, t1, 1
	add	t0, t0, t1
	lhu	t2, 0(t0)
	sw	t2, 12(sp)
	la	a1, gnu_hash_hit_versym_msg
	li	a2, gnu_hash_hit_versym_msg_len
	call	write_stdout
	lw	a0, 12(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	a0, 80(sp)
	lw	a1, 12(sp)
	call	enforce_gnuhash_versym
4:
	la	a1, resolved_external_value_msg
	li	a2, resolved_external_value_msg_len
	call	write_stdout
	la	t0, resolved_symbol_value_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
7:
	lw	t1, 12(sp)
	andi	t1, t1, 1
	bnez	t1, 9f
	lw	t0, 36(sp)
	addi	t0, t0, 1
	sw	t0, 36(sp)
	lw	t0, 28(sp)
	addi	t0, t0, 4
	sw	t0, 28(sp)
	j	1b
9:
	lw	ra, 92(sp)
	addi	sp, sp, 96
	ret

resolve_needed_symbol_table:
	addi	sp, sp, -80
	sw	ra, 76(sp)
	sw	a0, 72(sp)
	la	t0, resolved_symbol_found_slot
	sw	zero, 0(t0)
	la	t0, resolved_symbol_value_slot
	sw	zero, 0(t0)
	lw	a0, 72(sp)
	call	gnu_hash_name
	sw	a0, 36(sp)
	la	t0, needed_obj_count_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	sw	t1, 68(sp)
	sw	zero, 64(sp)
1:
	lw	t1, 68(sp)
	beqz	t1, 9f
	lw	t2, 64(sp)
	slli	t3, t2, 2
	la	t0, needed_obj_syment_buf
	add	t0, t0, t3
	lw	t4, 0(t0)
	li	t5, 16
	bltu	t4, t5, 8f
	la	t0, needed_obj_symtab_read_buf
	add	t0, t0, t3
	lw	t5, 0(t0)
	beqz	t5, 8f
	la	t0, needed_obj_symcount_buf
	add	t0, t0, t3
	lw	t6, 0(t0)
	beqz	t6, 10f
	mv	t5, t6
	j	11f
10:
	divu	t5, t5, t4
11:
	li	t6, 1
	bgeu	t6, t5, 8f
	sw	t5, 32(sp)
	addi	t5, t5, -1
	sw	t5, 60(sp)
	sw	t4, 56(sp)
	la	t0, needed_obj_strtab_read_buf
	add	t0, t0, t3
	lw	t5, 0(t0)
	sw	t5, 52(sp)
	la	t0, needed_obj_bias_buf
	add	t0, t0, t3
	lw	t5, 0(t0)
	sw	t5, 48(sp)
	la	t0, needed_obj_symtab_pool
	li	t5, NEEDED_OBJ_SYMTAB_BYTES
	mul	t6, t2, t5
	add	t0, t0, t6
	add	t0, t0, t4
	sw	t0, 44(sp)
	la	t0, needed_obj_strtab_pool
	li	t5, NEEDED_OBJ_STRTAB_BYTES
	mul	t6, t2, t5
	add	t0, t0, t6
	sw	t0, 40(sp)
	slli	t3, t2, 2
	la	t0, needed_obj_gnuhash_buf
	add	t0, t0, t3
	lw	a7, 0(t0)
	beqz	a7, 14f
	lw	a0, 72(sp)
	lw	a1, 36(sp)
	mv	a2, t2
	lw	a3, 56(sp)
	lw	a4, 32(sp)
	lw	a5, 52(sp)
	lw	a6, 48(sp)
	call	resolve_needed_symbol_gnuhash
	la	t0, resolved_symbol_found_slot
	lw	t0, 0(t0)
	bnez	t0, 9f
14:
2:
	lw	t1, 60(sp)
	beqz	t1, 8f
	lw	t0, 44(sp)
	lw	t2, 0(t0)
	lw	t3, 52(sp)
	bgeu	t2, t3, 7f
	lw	t4, 40(sp)
	add	t4, t4, t2
	lw	t2, 72(sp)
3:
	lbu	t5, 0(t2)
	lbu	t6, 0(t4)
	bne	t5, t6, 7f
	beqz	t5, 4f
	addi	t2, t2, 1
	addi	t4, t4, 1
	j	3b
4:
	lw	t0, 44(sp)
	lbu	t5, 12(t0)
	srli	t6, t5, 4
	li	t3, 1
	beq	t6, t3, 12f
	li	t3, 2
	beq	t6, t3, 12f
	j	7f
12:
	andi	t6, t5, 0x0f
	li	t3, 2
	bleu	t6, t3, 13f
	j	7f
13:
	lw	t2, 4(t0)
	beqz	t2, 7f
	sw	t0, 28(sp)
	lw	t3, 48(sp)
	add	t2, t2, t3
	sw	t2, 24(sp)
	la	t0, needed_obj_versym_buf
	lw	t1, 64(sp)
	slli	t1, t1, 2
	add	t0, t0, t1
	lw	t0, 0(t0)
	bnez	t0, .Lsymtab_have_versym
	lw	a0, 64(sp)
	la	a1, symtab_missing_versym_check_msg
	li	a2, 40
	call	enforce_missing_needed_versym_with_msg
	j	15f
.Lsymtab_have_versym:
	lw	t1, 32(sp)
	lw	t2, 60(sp)
	sub	t1, t1, t2
	slli	t1, t1, 1
	add	t0, t0, t1
	lhu	t2, 0(t0)
	sw	t2, 20(sp)
	la	a1, symtab_hit_versym_msg
	li	a2, symtab_hit_versym_msg_len
	call	write_stdout
	lw	a0, 20(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	a0, 64(sp)
	lw	a1, 20(sp)
	call	enforce_symtab_versym
15:
	lw	t2, 24(sp)
	la	t0, resolved_symbol_value_slot
	sw	t2, 0(t0)
	li	t2, 1
	la	t0, resolved_symbol_found_slot
	sw	t2, 0(t0)
	la	a1, resolved_external_msg
	li	a2, resolved_external_msg_len
	call	write_stdout
	lw	a1, 72(sp)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, resolved_external_value_msg
	li	a2, resolved_external_value_msg_len
	call	write_stdout
	la	t0, resolved_symbol_value_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
7:
	lw	t0, 44(sp)
	lw	t3, 56(sp)
	add	t0, t0, t3
	sw	t0, 44(sp)
	lw	t1, 60(sp)
	addi	t1, t1, -1
	sw	t1, 60(sp)
	j	2b
8:
	lw	t2, 64(sp)
	addi	t2, t2, 1
	sw	t2, 64(sp)
	lw	t1, 68(sp)
	addi	t1, t1, -1
	sw	t1, 68(sp)
	j	1b
9:
	lw	ra, 76(sp)
	addi	sp, sp, 80
	ret

probe_needed_libraries:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	la	t0, needed_obj_count_slot
	sw	zero, 0(t0)
	la	t0, dyn_needed_count_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	sw	t1, 20(sp)
	la	t0, dyn_needed_offsets_buf
	sw	t0, 16(sp)
1:
	lw	t1, 20(sp)
	beqz	t1, 9f
	lw	t0, 16(sp)
	lw	t2, 0(t0)
	la	t3, dyn_needed_slot
	sw	t2, 0(t3)
	la	t3, dyn_strtab_slot
	lw	t3, 0(t3)
	beqz	t3, 8f
	add	t3, t3, t2
	la	t5, needed_name_ptr_slot
	sw	t3, 0(t5)
	la	t3, needed_obj_count_slot
	lw	t4, 0(t3)
	la	t3, current_needed_obj_index_slot
	sw	t4, 0(t3)
	la	a1, needed_object_index_msg
	li	a2, needed_object_index_msg_len
	call	write_stdout
	la	t0, current_needed_obj_index_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_name_msg
	li	a2, needed_name_msg_len
	call	write_stdout
	la	t0, needed_name_ptr_slot
	lw	a1, 0(t0)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	probe_needed_library
8:
	lw	t0, 16(sp)
	addi	t0, t0, 4
	sw	t0, 16(sp)
	lw	t1, 20(sp)
	addi	t1, t1, -1
	sw	t1, 20(sp)
	j	1b
9:
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

is_needed_name_loaded:
	addi	sp, sp, -32
	la	t0, needed_name_loaded_slot
	sw	zero, 0(t0)
	la	t0, needed_name_ptr_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_obj_count_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	sw	zero, 24(sp)
	sw	t2, 20(sp)
1:
	lw	t2, 20(sp)
	beqz	t2, 9f
	lw	t3, 24(sp)
	la	t4, needed_obj_name_pool
	li	t5, NEEDED_OBJ_NAME_BYTES
	mul	t6, t3, t5
	add	t4, t4, t6
	la	t0, needed_name_ptr_slot
	lw	t1, 0(t0)
	li	t5, NEEDED_OBJ_NAME_BYTES
2:
	beqz	t5, 4f
	lbu	t6, 0(t1)
	lbu	t0, 0(t4)
	bne	t6, t0, 4f
	beqz	t6, 3f
	addi	t1, t1, 1
	addi	t4, t4, 1
	addi	t5, t5, -1
	j	2b
3:
	li	t0, 1
	la	t1, needed_name_loaded_slot
	sw	t0, 0(t1)
	j	9f
4:
	lw	t3, 24(sp)
	addi	t3, t3, 1
	sw	t3, 24(sp)
	lw	t2, 20(sp)
	addi	t2, t2, -1
	sw	t2, 20(sp)
	j	1b
9:
	addi	sp, sp, 32
	ret

probe_needed_library:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_fd_slot
	li	t1, -1
	sw	t1, 0(t0)
	la	t1, needed_name_ptr_slot
	lw	t1, 0(t1)
	beqz	t1, 9f
	call	is_needed_name_loaded
	la	t0, needed_name_loaded_slot
	lw	t0, 0(t0)
	beqz	t0, 11f
	la	a1, needed_duplicate_msg
	li	a2, needed_duplicate_msg_len
	call	write_stdout
	la	t0, needed_name_ptr_slot
	lw	a1, 0(t0)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
11:
	la	a0, needed_name_ptr_slot
	lw	a0, 0(a0)
	la	a1, needed_current_name_buf
	li	a2, NEEDED_OBJ_NAME_BYTES
	call	copy_cstr_bounded
	la	t1, needed_current_name_buf
	la	t0, needed_name_ptr_slot
	sw	t1, 0(t0)

	la	t3, needed_path_buf
	la	t4, needed_path_prefix
	li	t5, needed_path_prefix_len
1:
	beqz	t5, 2f
	lbu	t6, 0(t4)
	sb	t6, 0(t3)
	addi	t4, t4, 1
	addi	t3, t3, 1
	addi	t5, t5, -1
	j	1b
2:
	li	t4, 0
	li	t5, 120
3:
	bgeu	t4, t5, 4f
	lbu	t6, 0(t1)
	sb	t6, 0(t3)
	beqz	t6, 5f
	addi	t1, t1, 1
	addi	t3, t3, 1
	addi	t4, t4, 1
	j	3b
4:
	sb	zero, 0(t3)
5:
	la	a1, needed_path_msg
	li	a2, needed_path_msg_len
	call	write_stdout
	la	a1, needed_path_buf
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	li	a0, AT_FDCWD
	la	a1, needed_path_buf
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, 8f
	la	t0, needed_fd_slot
	sw	a0, 0(t0)

	la	a1, needed_elf_header
	li	a2, 256
	li	a7, SYS_READ
	ecall
	la	t0, needed_read_slot
	sw	a0, 0(t0)
	la	t0, needed_read_slot
	lw	a0, 0(t0)
	bltz	a0, 8f

	la	a1, needed_read_msg
	li	a2, needed_read_msg_len
	call	write_stdout
	la	t0, needed_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	t0, needed_read_slot
	lw	t0, 0(t0)
	li	t1, 52
	bltu	t0, t1, 7f
	la	t0, needed_elf_header
	lw	t1, 0(t0)
	li	t2, 0x464c457f
	bne	t1, t2, 7f
	lbu	t1, 4(t0)
	li	t2, 1
	bne	t1, t2, 7f
	lhu	t1, 18(t0)
	li	t2, EM_RISCV
	bne	t1, t2, 7f
	lhu	t1, 16(t0)
	li	t2, ET_DYN
	bne	t1, t2, 7f

	la	a1, needed_type_msg
	li	a2, needed_type_msg_len
	call	write_stdout
	la	t0, needed_elf_header
	lhu	a0, 16(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_entry_msg
	li	a2, needed_entry_msg_len
	call	write_stdout
	la	t0, needed_elf_header
	lw	a0, 24(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_phoff_msg
	li	a2, needed_phoff_msg_len
	call	write_stdout
	la	t0, needed_elf_header
	lw	a0, 28(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_phnum_msg
	li	a2, needed_phnum_msg_len
	call	write_stdout
	la	t0, needed_elf_header
	lhu	a0, 44(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	probe_needed_phdrs
	call	load_needed_segments
	call	probe_needed_dynamic
	call	apply_needed_relocations
	call	register_needed_object
	call	close_needed_fd
	call	load_transitive_needed_libraries
	la	a1, needed_ok_msg
	li	a2, needed_ok_msg_len
	call	write_stdout
	j	9f
7:
	la	a1, needed_bad_elf_msg
	li	a2, needed_bad_elf_msg_len
	call	write_stdout
	j	9f
8:
	mv	t0, a0
	la	a1, needed_open_fail_msg
	li	a2, needed_open_fail_msg_len
	call	write_stdout
	mv	a0, t0
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 10f
	li	a7, SYS_CLOSE
	ecall
	la	t0, needed_fd_slot
	li	t1, -1
	sw	t1, 0(t0)
10:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

close_needed_fd:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 1f
	li	a7, SYS_CLOSE
	ecall
	la	t0, needed_fd_slot
	li	t1, -1
	sw	t1, 0(t0)
1:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

load_transitive_needed_libraries:
	addi	sp, sp, -TRANSITIVE_FRAME_BYTES
	sw	ra, TRANSITIVE_NAME_POOL_BYTES + 44(sp)
	la	t0, needed_lib_needed_count_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	li	t2, MAX_TRANSITIVE_NEEDED
	bleu	t1, t2, 1f
	mv	t1, t2
1:
	sw	t1, TRANSITIVE_NAME_POOL_BYTES + 40(sp)
	sw	zero, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
2:
	lw	t1, TRANSITIVE_NAME_POOL_BYTES + 40(sp)
	lw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	bgeu	t2, t1, 5f
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t2, t3
	add	t5, sp, t4
	sb	zero, 0(t5)
	la	t0, needed_lib_needed_offsets_buf
	slli	t6, t2, 2
	add	t0, t0, t6
	lw	t6, 0(t0)
	la	t0, needed_strtab_read_slot
	lw	t0, 0(t0)
	bgeu	t6, t0, 4f
	la	a0, needed_strtab_buf
	add	a0, a0, t6
	mv	a1, t5
	li	a2, NEEDED_OBJ_NAME_BYTES
	call	copy_cstr_bounded
4:
	lw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	addi	t2, t2, 1
	sw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	j	2b
5:
	sw	zero, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
6:
	lw	t1, TRANSITIVE_NAME_POOL_BYTES + 40(sp)
	lw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	bgeu	t2, t1, 9f
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t2, t3
	add	t5, sp, t4
	lbu	t6, 0(t5)
	beqz	t6, 8f
	la	t0, needed_obj_count_slot
	lw	t3, 0(t0)
	li	t4, MAX_NEEDED_OBJECTS
	bgeu	t3, t4, 9f
	la	t0, current_needed_obj_index_slot
	sw	t3, 0(t0)
	la	t0, needed_name_ptr_slot
	sw	t5, 0(t0)
	la	a1, needed_transitive_msg
	li	a2, needed_transitive_msg_len
	call	write_stdout
	la	t0, needed_name_ptr_slot
	lw	a1, 0(t0)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	probe_needed_library
8:
	lw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	addi	t2, t2, 1
	sw	t2, TRANSITIVE_NAME_POOL_BYTES + 36(sp)
	j	6b
9:
	lw	ra, TRANSITIVE_NAME_POOL_BYTES + 44(sp)
	addi	sp, sp, TRANSITIVE_FRAME_BYTES
	ret

probe_needed_phdrs:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_elf_header
	lw	t1, 28(t0)
	lhu	t2, 44(t0)
	lhu	t3, 42(t0)
	beqz	t1, 9f
	beqz	t2, 9f
	beqz	t3, 9f
	la	t4, needed_read_slot
	lw	t4, 0(t4)
	mul	t5, t2, t3
	add	t5, t5, t1
	bltu	t4, t5, 9f
	add	t0, t0, t1
1:
	beqz	t2, 9f
	lw	t4, 0(t0)
	li	t5, PT_DYNAMIC
	bne	t4, t5, 2f
	sw	t0, 8(sp)
	lw	t1, 4(t0)
	la	t6, needed_dynamic_off_slot
	sw	t1, 0(t6)
	lw	t1, 8(t0)
	la	t6, needed_dynamic_vaddr_slot
	sw	t1, 0(t6)
	lw	t1, 16(t0)
	la	t6, needed_dynamic_size_slot
	sw	t1, 0(t6)
	la	a1, needed_dynamic_off_msg
	li	a2, needed_dynamic_off_msg_len
	call	write_stdout
	lw	t0, 8(sp)
	lw	a0, 4(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dynamic_vaddr_msg
	li	a2, needed_dynamic_vaddr_msg_len
	call	write_stdout
	lw	t0, 8(sp)
	lw	a0, 8(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dynamic_size_msg
	li	a2, needed_dynamic_size_msg_len
	call	write_stdout
	lw	t0, 8(sp)
	lw	a0, 16(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
2:
	add	t0, t0, t3
	addi	t2, t2, -1
	j	1b
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

load_needed_segments:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	la	t0, needed_load_min_vaddr_slot
	li	t1, -1
	sw	t1, 0(t0)
	la	t0, needed_load_max_vaddr_slot
	sw	zero, 0(t0)
	la	t0, needed_load_count_slot
	sw	zero, 0(t0)
	la	t0, needed_elf_header
	lw	t1, 28(t0)
	lhu	t2, 44(t0)
	lhu	t3, 42(t0)
	beqz	t1, 9f
	beqz	t2, 9f
	beqz	t3, 9f
	add	t0, t0, t1
1:
	beqz	t2, 2f
	lw	t4, 0(t0)
	li	t5, PT_LOAD
	bne	t4, t5, 3f
	lw	t4, 8(t0)
	la	t5, needed_load_min_vaddr_slot
	lw	t6, 0(t5)
	bleu	t6, t4, 4f
	sw	t4, 0(t5)
4:
	lw	t5, 20(t0)
	add	t5, t5, t4
	la	t6, needed_load_max_vaddr_slot
	lw	t4, 0(t6)
	bleu	t5, t4, 5f
	sw	t5, 0(t6)
5:
	la	t4, needed_load_count_slot
	lw	t5, 0(t4)
	addi	t5, t5, 1
	sw	t5, 0(t4)
3:
	add	t0, t0, t3
	addi	t2, t2, -1
	j	1b
2:
	la	t0, needed_load_count_slot
	lw	t0, 0(t0)
	beqz	t0, 9f
	la	t0, needed_load_min_vaddr_slot
	lw	t1, 0(t0)
	la	t0, needed_load_max_vaddr_slot
	lw	t2, 0(t0)
	bltu	t2, t1, 9f
	sub	t3, t2, t1
	li	t4, 0x4000
	bltu	t4, t3, 9f
	la	t4, current_needed_obj_index_slot
	lw	t4, 0(t4)
	li	t5, 0x00100000
	mul	t4, t4, t5
	li	t5, 0x02000000
	add	t4, t4, t5
	la	t5, needed_load_base_slot
	sw	t4, 0(t5)
	sub	t5, t4, t1
	la	t6, needed_load_bias_slot
	sw	t5, 0(t6)
	sw	t3, 24(sp)
	la	a1, needed_load_base_msg
	li	a2, needed_load_base_msg_len
	call	write_stdout
	la	t0, needed_load_base_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_load_min_msg
	li	a2, needed_load_min_msg_len
	call	write_stdout
	la	t0, needed_load_min_vaddr_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_load_span_msg
	li	a2, needed_load_span_msg_len
	call	write_stdout
	lw	a0, 24(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_load_bias_msg
	li	a2, needed_load_bias_msg_len
	call	write_stdout
	la	t0, needed_load_bias_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	copy_needed_load_segments
9:
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

copy_needed_load_segments:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	la	t0, needed_elf_header
	lw	t1, 28(t0)
	lhu	t2, 44(t0)
	lhu	t3, 42(t0)
	beqz	t1, 9f
	beqz	t2, 9f
	beqz	t3, 9f
	sw	t3, 16(sp)
	add	t0, t0, t1
1:
	beqz	t2, 9f
	sw	t0, 24(sp)
	sw	t2, 20(sp)
	lw	t4, 0(t0)
	li	t5, PT_LOAD
	bne	t4, t5, 2f
	lw	t4, 16(t0)
	beqz	t4, 2f
	lw	t5, 8(t0)
	la	t6, needed_load_min_vaddr_slot
	lw	t6, 0(t6)
	sub	t5, t5, t6
	la	t6, needed_load_base_slot
	lw	t6, 0(t6)
	add	t5, t5, t6
	la	t6, needed_load_seg_dst_slot
	sw	t5, 0(t6)
	la	a1, needed_load_seg_vaddr_msg
	li	a2, needed_load_seg_vaddr_msg_len
	call	write_stdout
	lw	t0, 24(sp)
	lw	a0, 8(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_load_seg_dst_msg
	li	a2, needed_load_seg_dst_msg_len
	call	write_stdout
	la	t0, needed_load_seg_dst_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_load_seg_dst_slot
	lw	t4, 0(t0)
	li	t5, 0xfffff000
	and	a0, t4, t5
	la	t6, needed_load_seg_map_slot
	sw	a0, 0(t6)
	lw	t0, 24(sp)
	lw	a1, 20(t0)
	li	t6, 0xfff
	and	t4, t4, t6
	add	a1, a1, t4
	add	a1, a1, t6
	and	a1, a1, t5
	beqz	a1, 2f
	lw	t4, 24(t0)
	li	a2, 0
	andi	t6, t4, 4
	beqz	t6, 3f
	ori	a2, a2, PROT_READ
3:
	andi	t6, t4, 2
	beqz	t6, 4f
	ori	a2, a2, PROT_WRITE
4:
	andi	t6, t4, 1
	beqz	t6, 5f
	ori	a2, a2, PROT_EXEC
5:
	beqz	a2, 2f
	li	a3, MAP_PRIVATE | MAP_FIXED
	la	t6, needed_fd_slot
	lw	a4, 0(t6)
	bltz	a4, 2f
	lw	a5, 4(t0)
	and	a5, a5, t5
	la	a1, needed_load_seg_map_msg
	li	a2, needed_load_seg_map_msg_len
	call	write_stdout
	la	t0, needed_load_seg_map_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_load_seg_map_slot
	lw	a0, 0(t0)
	lw	t0, 24(sp)
	lw	a1, 20(t0)
	la	t4, needed_load_seg_dst_slot
	lw	t4, 0(t4)
	li	t6, 0xfff
	and	t4, t4, t6
	add	a1, a1, t4
	add	a1, a1, t6
	li	t5, 0xfffff000
	and	a1, a1, t5
	lw	t4, 24(t0)
	li	a2, 0
	andi	t6, t4, 4
	beqz	t6, 6f
	ori	a2, a2, PROT_READ
6:
	andi	t6, t4, 2
	beqz	t6, 7f
	ori	a2, a2, PROT_WRITE
7:
	andi	t6, t4, 1
	beqz	t6, 8f
	ori	a2, a2, PROT_EXEC
8:
	li	a3, MAP_PRIVATE | MAP_FIXED
	la	t4, needed_fd_slot
	lw	a4, 0(t4)
	lw	a5, 4(t0)
	and	a5, a5, t5
	li	a7, SYS_MMAP
	ecall
	la	t0, needed_load_seg_read_slot
	sw	a0, 0(t0)
	bltz	a0, 2f
	la	a1, needed_load_seg_mmap_ret_msg
	li	a2, needed_load_seg_mmap_ret_msg_len
	call	write_stdout
	la	t0, needed_load_seg_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
2:
	lw	t0, 24(sp)
	lw	t2, 20(sp)
	lw	t3, 16(sp)
	add	t0, t0, t3
	addi	t2, t2, -1
	j	1b
9:
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

copy_bytes:
	beqz	a2, 2f
1:
	lbu	t0, 0(a0)
	sb	t0, 0(a1)
	addi	a0, a0, 1
	addi	a1, a1, 1
	addi	a2, a2, -1
	bnez	a2, 1b
2:
	ret

copy_cstr_bounded:
	beqz	a2, 3f
1:
	lbu	t0, 0(a0)
	sb	t0, 0(a1)
	addi	a0, a0, 1
	addi	a1, a1, 1
	addi	a2, a2, -1
	beqz	t0, 3f
	addi	t1, a2, -1
	bgez	t1, 1b
	sb	zero, -1(a1)
3:
	ret

probe_needed_dynamic:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 9f
	la	t0, needed_dynamic_off_slot
	lw	a2, 0(t0)
	beqz	a2, 9f
	li	a1, 0
	la	a3, needed_seek_result
	li	a4, SEEK_SET
	li	a7, SYS_LLSEEK
	ecall
	bltz	a0, 9f
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	la	a1, needed_dynamic_buf
	li	a2, NEEDED_DYNAMIC_BYTES
	la	t0, needed_dynamic_size_slot
	lw	t0, 0(t0)
	beqz	t0, 1f
	bgeu	t0, a2, 1f
	mv	a2, t0
1:
	li	a7, SYS_READ
	ecall
	la	t0, needed_dynamic_read_slot
	sw	a0, 0(t0)
	bltz	a0, 9f
	la	a1, needed_dynamic_read_msg
	li	a2, needed_dynamic_read_msg_len
	call	write_stdout
	la	t0, needed_dynamic_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	parse_needed_dynamic_table
	call	print_needed_dynamic_slots
	call	read_needed_strtab
	call	read_needed_hash
	call	read_needed_gnu_hash
	call	read_needed_versym
	call	read_needed_verdef
	call	read_needed_symtab
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

parse_needed_dynamic_table:
	la	t0, needed_lib_strtab_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_strsz_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_hash_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_gnuhash_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_gnuhash_runtime_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_gnuhash_symoffset_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_versym_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_versym_runtime_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verdef_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verdefnum_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verdef_ndx_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verdef_hash_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verdef_name_off_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verneed_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_verneednum_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_symcount_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_symtab_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_syment_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_soname_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_needed_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_needed_count_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_rel_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_relsz_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_relent_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_jmprel_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_pltrelsz_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_pltrel_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_init_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_init_array_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_init_arraysz_slot
	sw	zero, 0(t0)
	la	t0, needed_dynamic_buf
	la	t1, needed_dynamic_read_slot
	lw	t1, 0(t1)
	li	t2, 8
	divu	t1, t1, t2
	li	t3, NEEDED_DYNAMIC_BYTES / 8
	bleu	t1, t3, 1f
	mv	t1, t3
1:
	beqz	t1, 9f
	lw	t2, 0(t0)
	lw	t3, 4(t0)
	li	t4, DT_NULL
	beq	t2, t4, 9f
	li	t4, DT_STRTAB
	bne	t2, t4, 2f
	la	t5, needed_lib_strtab_slot
	sw	t3, 0(t5)
	j	8f
2:
	li	t4, DT_STRSZ
	bne	t2, t4, 3f
	la	t5, needed_lib_strsz_slot
	sw	t3, 0(t5)
	j	8f
3:
	li	t4, DT_HASH
	bne	t2, t4, 21f
	la	t5, needed_lib_hash_slot
	sw	t3, 0(t5)
	j	8f
21:
	li	t4, DT_GNU_HASH
	bne	t2, t4, 22f
	la	t5, needed_lib_gnuhash_slot
	sw	t3, 0(t5)
	j	8f
22:
	li	t4, DT_VERSYM
	bne	t2, t4, 23f
	la	t5, needed_lib_versym_slot
	sw	t3, 0(t5)
	j	8f
23:
	li	t4, DT_VERDEF
	bne	t2, t4, 24f
	la	t5, needed_lib_verdef_slot
	sw	t3, 0(t5)
	j	8f
24:
	li	t4, DT_VERDEFNUM
	bne	t2, t4, 25f
	la	t5, needed_lib_verdefnum_slot
	sw	t3, 0(t5)
	j	8f
25:
	li	t4, DT_VERNEED
	bne	t2, t4, 26f
	la	t5, needed_lib_verneed_slot
	sw	t3, 0(t5)
	j	8f
26:
	li	t4, DT_VERNEEDNUM
	bne	t2, t4, 27f
	la	t5, needed_lib_verneednum_slot
	sw	t3, 0(t5)
	j	8f
27:
	li	t4, DT_SYMTAB
	bne	t2, t4, 4f
	la	t5, needed_lib_symtab_slot
	sw	t3, 0(t5)
	j	8f
4:
	li	t4, DT_SYMENT
	bne	t2, t4, 5f
	la	t5, needed_lib_syment_slot
	sw	t3, 0(t5)
	j	8f
5:
	li	t4, DT_SONAME
	bne	t2, t4, 6f
	la	t5, needed_lib_soname_slot
	sw	t3, 0(t5)
	j	8f
6:
	li	t4, DT_NEEDED
	bne	t2, t4, 7f
	la	t5, needed_lib_needed_count_slot
	lw	t6, 0(t5)
	bnez	t6, 17f
	la	t4, needed_lib_needed_slot
	sw	t3, 0(t4)
17:
	li	t4, MAX_TRANSITIVE_NEEDED
	bgeu	t6, t4, 8f
	la	t4, needed_lib_needed_offsets_buf
	slli	t6, t6, 2
	add	t4, t4, t6
	sw	t3, 0(t4)
	la	t4, needed_lib_needed_count_slot
	lw	t6, 0(t4)
	addi	t6, t6, 1
	sw	t6, 0(t4)
	j	8f
7:
	li	t4, DT_INIT
	bne	t2, t4, 12f
	la	t5, needed_lib_init_slot
	sw	t3, 0(t5)
	j	8f
12:
	li	t4, DT_INIT_ARRAY
	bne	t2, t4, 13f
	la	t5, needed_lib_init_array_slot
	sw	t3, 0(t5)
	j	8f
13:
	li	t4, DT_INIT_ARRAYSZ
	bne	t2, t4, 14f
	la	t5, needed_lib_init_arraysz_slot
	sw	t3, 0(t5)
	j	8f
14:
	li	t4, DT_REL
	bne	t2, t4, 15f
	la	t5, needed_lib_rel_slot
	sw	t3, 0(t5)
	j	8f
15:
	li	t4, DT_RELSZ
	bne	t2, t4, 16f
	la	t5, needed_lib_relsz_slot
	sw	t3, 0(t5)
	j	8f
16:
	li	t4, DT_RELENT
	bne	t2, t4, 18f
	la	t5, needed_lib_relent_slot
	sw	t3, 0(t5)
	j	8f
18:
	li	t4, DT_JMPREL
	bne	t2, t4, 19f
	la	t5, needed_lib_jmprel_slot
	sw	t3, 0(t5)
	j	8f
19:
	li	t4, DT_PLTRELSZ
	bne	t2, t4, 20f
	la	t5, needed_lib_pltrelsz_slot
	sw	t3, 0(t5)
	j	8f
20:
	li	t4, DT_PLTREL
	bne	t2, t4, 8f
	la	t5, needed_lib_pltrel_slot
	sw	t3, 0(t5)
8:
	addi	t0, t0, 8
	addi	t1, t1, -1
	j	1b
9:
	ret

print_needed_dynamic_slots:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	a1, needed_dt_strtab_msg
	li	a2, needed_dt_strtab_msg_len
	call	write_stdout
	la	t0, needed_lib_strtab_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_strsz_msg
	li	a2, needed_dt_strsz_msg_len
	call	write_stdout
	la	t0, needed_lib_strsz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_hash_msg
	li	a2, needed_dt_hash_msg_len
	call	write_stdout
	la	t0, needed_lib_hash_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_gnuhash_msg
	li	a2, needed_dt_gnuhash_msg_len
	call	write_stdout
	la	t0, needed_lib_gnuhash_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_versym_msg
	li	a2, needed_dt_versym_msg_len
	call	write_stdout
	la	t0, needed_lib_versym_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_verdef_msg
	li	a2, needed_dt_verdef_msg_len
	call	write_stdout
	la	t0, needed_lib_verdef_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_verdefnum_msg
	li	a2, needed_dt_verdefnum_msg_len
	call	write_stdout
	la	t0, needed_lib_verdefnum_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_verneed_msg
	li	a2, needed_dt_verneed_msg_len
	call	write_stdout
	la	t0, needed_lib_verneed_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_verneednum_msg
	li	a2, needed_dt_verneednum_msg_len
	call	write_stdout
	la	t0, needed_lib_verneednum_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_symtab_msg
	li	a2, needed_dt_symtab_msg_len
	call	write_stdout
	la	t0, needed_lib_symtab_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_syment_msg
	li	a2, needed_dt_syment_msg_len
	call	write_stdout
	la	t0, needed_lib_syment_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_soname_msg
	li	a2, needed_dt_soname_msg_len
	call	write_stdout
	la	t0, needed_lib_soname_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_needed_msg
	li	a2, needed_dt_needed_msg_len
	call	write_stdout
	la	t0, needed_lib_needed_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_needed_count_msg
	li	a2, needed_dt_needed_count_msg_len
	call	write_stdout
	la	t0, needed_lib_needed_count_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_rel_msg
	li	a2, needed_dt_rel_msg_len
	call	write_stdout
	la	t0, needed_lib_rel_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_relsz_msg
	li	a2, needed_dt_relsz_msg_len
	call	write_stdout
	la	t0, needed_lib_relsz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_relent_msg
	li	a2, needed_dt_relent_msg_len
	call	write_stdout
	la	t0, needed_lib_relent_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_jmprel_msg
	li	a2, needed_dt_jmprel_msg_len
	call	write_stdout
	la	t0, needed_lib_jmprel_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_pltrelsz_msg
	li	a2, needed_dt_pltrelsz_msg_len
	call	write_stdout
	la	t0, needed_lib_pltrelsz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_pltrel_msg
	li	a2, needed_dt_pltrel_msg_len
	call	write_stdout
	la	t0, needed_lib_pltrel_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_init_msg
	li	a2, needed_dt_init_msg_len
	call	write_stdout
	la	t0, needed_lib_init_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_init_array_msg
	li	a2, needed_dt_init_array_msg_len
	call	write_stdout
	la	t0, needed_lib_init_array_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_dt_init_arraysz_msg
	li	a2, needed_dt_init_arraysz_msg_len
	call	write_stdout
	la	t0, needed_lib_init_arraysz_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_strtab:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_strtab_slot
	lw	a0, 0(t0)
	beqz	a0, 9f
	call	needed_vaddr_to_file_off
	beqz	a1, 9f
	la	t0, needed_strtab_off_slot
	sw	a0, 0(t0)
	la	a1, needed_strtab_off_msg
	li	a2, needed_strtab_off_msg_len
	call	write_stdout
	la	t0, needed_strtab_off_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 9f
	li	a1, 0
	la	t0, needed_strtab_off_slot
	lw	a2, 0(t0)
	la	a3, needed_seek_result
	li	a4, SEEK_SET
	li	a7, SYS_LLSEEK
	ecall
	bltz	a0, 9f
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	la	a1, needed_strtab_buf
	la	t0, needed_lib_strsz_slot
	lw	t0, 0(t0)
	beqz	t0, 9f
	li	a2, NEEDED_OBJ_STRTAB_BYTES
	bgeu	t0, a2, 1f
	mv	a2, t0
1:
	li	a7, SYS_READ
	ecall
	la	t0, needed_strtab_read_slot
	sw	a0, 0(t0)
	bltz	a0, 9f
	la	a1, needed_strtab_read_msg
	li	a2, needed_strtab_read_msg_len
	call	write_stdout
	la	t0, needed_strtab_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_lib_soname_slot
	lw	t0, 0(t0)
	la	t1, needed_strtab_read_slot
	lw	t1, 0(t1)
	bgeu	t0, t1, 9f
	la	a1, needed_soname_name_msg
	li	a2, needed_soname_name_msg_len
	call	write_stdout
	la	a1, needed_strtab_buf
	add	a1, a1, t0
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_hash:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_symcount_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_hash_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_load_bias_slot
	lw	t2, 0(t0)
	add	t1, t1, t2
	lw	t3, 4(t1)
	beqz	t3, 9f
	la	t0, needed_lib_symcount_slot
	sw	t3, 0(t0)
	la	a1, needed_hash_nchain_msg
	li	a2, needed_hash_nchain_msg_len
	call	write_stdout
	la	t0, needed_lib_symcount_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_gnu_hash:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_gnuhash_runtime_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_gnuhash_symoffset_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_gnuhash_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_load_bias_slot
	lw	t2, 0(t0)
	add	t1, t1, t2
	sw	t1, 8(sp)
	la	t0, needed_lib_gnuhash_runtime_slot
	sw	t1, 0(t0)
	lw	t3, 0(t1)
	beqz	t3, 9f
	sw	t3, 4(sp)
	la	a1, needed_gnuhash_nbucket_msg
	li	a2, needed_gnuhash_nbucket_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t3, 4(t1)
	la	t0, needed_lib_gnuhash_symoffset_slot
	sw	t3, 0(t0)
	sw	t3, 4(sp)
	la	a1, needed_gnuhash_symoffset_msg
	li	a2, needed_gnuhash_symoffset_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t3, 8(t1)
	beqz	t3, 9f
	sw	t3, 4(sp)
	la	a1, needed_gnuhash_bloom_size_msg
	li	a2, needed_gnuhash_bloom_size_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t3, 12(t1)
	sw	t3, 4(sp)
	la	a1, needed_gnuhash_bloom_shift_msg
	li	a2, needed_gnuhash_bloom_shift_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t3, 8(t1)
	slli	t3, t3, 2
	addi	t3, t3, 16
	add	t3, t1, t3
	lw	t3, 0(t3)
	sw	t3, 4(sp)
	la	a1, needed_gnuhash_bucket0_msg
	li	a2, needed_gnuhash_bucket0_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_versym:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_versym_runtime_slot
	sw	zero, 0(t0)
	la	t0, needed_lib_versym_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_lib_symcount_slot
	lw	t2, 0(t0)
	li	t3, 2
	bltu	t2, t3, 9f
	la	t0, needed_load_bias_slot
	lw	t3, 0(t0)
	add	t1, t1, t3
	sw	t1, 8(sp)
	la	t0, needed_lib_versym_runtime_slot
	sw	t1, 0(t0)
	la	a1, needed_versym_runtime_msg
	li	a2, needed_versym_runtime_msg_len
	call	write_stdout
	lw	a0, 8(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lhu	t3, 2(t1)
	sw	t3, 4(sp)
	la	a1, needed_versym1_msg
	li	a2, needed_versym1_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_lib_symcount_slot
	lw	t2, 0(t0)
	li	t3, 3
	bltu	t2, t3, 9f
	lw	t1, 8(sp)
	lhu	t3, 4(t1)
	sw	t3, 4(sp)
	la	a1, needed_versym2_msg
	li	a2, needed_versym2_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_lib_symcount_slot
	lw	t2, 0(t0)
	li	t3, 4
	bltu	t2, t3, 9f
	lw	t1, 8(sp)
	lhu	t3, 6(t1)
	sw	t3, 4(sp)
	la	a1, needed_versym3_msg
	li	a2, needed_versym3_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_verdef:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_verdef_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_lib_verdefnum_slot
	lw	t2, 0(t0)
	beqz	t2, 9f
	la	t0, needed_load_bias_slot
	lw	t3, 0(t0)
	add	t1, t1, t3
	sw	t1, 8(sp)
	la	a1, needed_verdef_runtime_msg
	li	a2, needed_verdef_runtime_msg_len
	call	write_stdout
	lw	a0, 8(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lhu	t2, 4(t1)
	la	t0, needed_lib_verdef_ndx_slot
	sw	t2, 0(t0)
	sw	t2, 4(sp)
	la	a1, needed_verdef_ndx_msg
	li	a2, needed_verdef_ndx_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t2, 8(t1)
	la	t0, needed_lib_verdef_hash_slot
	sw	t2, 0(t0)
	sw	t2, 4(sp)
	la	a1, needed_verdef_hash_msg
	li	a2, needed_verdef_hash_msg_len
	call	write_stdout
	lw	a0, 4(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t1, 8(sp)
	lw	t2, 12(t1)
	beqz	t2, 9f
	add	t1, t1, t2
	lw	t2, 0(t1)
	la	t0, needed_lib_verdef_name_off_slot
	sw	t2, 0(t0)
	la	t0, needed_strtab_read_slot
	lw	t3, 0(t0)
	bgeu	t2, t3, 9f
	la	a1, needed_verdef_name_msg
	li	a2, needed_verdef_name_msg_len
	call	write_stdout
	la	a1, needed_strtab_buf
	add	a1, a1, t2
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_needed_symtab:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_lib_symtab_slot
	lw	a0, 0(t0)
	beqz	a0, 9f
	la	t0, needed_lib_syment_slot
	lw	t0, 0(t0)
	li	t1, 16
	bltu	t0, t1, 9f
	call	needed_vaddr_to_file_off
	beqz	a1, 9f
	la	t0, needed_symtab_off_slot
	sw	a0, 0(t0)
	la	a1, needed_symtab_off_msg
	li	a2, needed_symtab_off_msg_len
	call	write_stdout
	la	t0, needed_symtab_off_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 9f
	li	a1, 0
	la	t0, needed_symtab_off_slot
	lw	a2, 0(t0)
	la	a3, needed_seek_result
	li	a4, SEEK_SET
	li	a7, SYS_LLSEEK
	ecall
	bltz	a0, 9f
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	la	a1, needed_symtab_buf
	li	a2, NEEDED_OBJ_SYMTAB_BYTES
	la	t0, needed_lib_symcount_slot
	lw	t1, 0(t0)
	beqz	t1, 1f
	la	t0, needed_lib_syment_slot
	lw	t2, 0(t0)
	mul	t1, t1, t2
	bgeu	t1, a2, 1f
	mv	a2, t1
1:
	li	a7, SYS_READ
	ecall
	la	t0, needed_symtab_read_slot
	sw	a0, 0(t0)
	bltz	a0, 9f
	la	a1, needed_symtab_read_msg
	li	a2, needed_symtab_read_msg_len
	call	write_stdout
	la	t0, needed_symtab_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_lib_syment_slot
	lw	t0, 0(t0)
	la	t1, needed_symtab_read_slot
	lw	t1, 0(t1)
	slli	t2, t0, 1
	bltu	t1, t2, 9f
	la	t1, needed_symtab_buf
	add	t1, t1, t0
	lw	t2, 0(t1)
	la	t3, needed_sym1_name_off_slot
	sw	t2, 0(t3)
	lw	t2, 4(t1)
	la	t3, needed_sym1_value_slot
	sw	t2, 0(t3)
	lw	t2, 8(t1)
	la	t3, needed_sym1_size_slot
	sw	t2, 0(t3)
	la	t0, needed_sym1_name_off_slot
	lw	t0, 0(t0)
	la	t1, needed_strtab_read_slot
	lw	t1, 0(t1)
	bgeu	t0, t1, 1f
	la	a1, needed_sym1_name_msg
	li	a2, needed_sym1_name_msg_len
	call	write_stdout
	la	a1, needed_strtab_buf
	add	a1, a1, t0
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
1:
	la	a1, needed_sym1_value_msg
	li	a2, needed_sym1_value_msg_len
	call	write_stdout
	la	t0, needed_sym1_value_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_sym1_size_msg
	li	a2, needed_sym1_size_msg_len
	call	write_stdout
	la	t0, needed_sym1_size_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	call	materialize_needed_sym1
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

materialize_needed_sym1:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, needed_sym1_runtime_addr_slot
	sw	zero, 0(t0)
	la	t0, needed_sym1_value_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	la	t0, needed_load_base_slot
	lw	t0, 0(t0)
	beqz	t0, 1f
	la	t0, needed_load_bias_slot
	lw	t2, 0(t0)
	add	t1, t1, t2
	la	t0, needed_sym1_runtime_addr_slot
	sw	t1, 0(t0)
	la	a1, needed_sym1_runtime_msg
	li	a2, needed_sym1_runtime_msg_len
	call	write_stdout
	la	t0, needed_sym1_runtime_addr_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	j	9f
1:
	mv	a0, t1
	call	needed_vaddr_to_file_off
	beqz	a1, 9f
	la	t0, needed_sym1_file_off_slot
	sw	a0, 0(t0)
	la	a1, needed_sym1_file_off_msg
	li	a2, needed_sym1_file_off_msg_len
	call	write_stdout
	la	t0, needed_sym1_file_off_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	bltz	a0, 9f
	li	a1, 0
	la	t0, needed_sym1_file_off_slot
	lw	a2, 0(t0)
	la	a3, needed_seek_result
	li	a4, SEEK_SET
	li	a7, SYS_LLSEEK
	ecall
	bltz	a0, 9f
	la	t0, needed_fd_slot
	lw	a0, 0(t0)
	la	a1, needed_sym1_runtime_buf
	li	a2, 4
	la	t0, needed_sym1_size_slot
	lw	t0, 0(t0)
	beqz	t0, 9f
	bgeu	t0, a2, 1f
	mv	a2, t0
1:
	li	a7, SYS_READ
	ecall
	la	t0, needed_sym1_data_read_slot
	sw	a0, 0(t0)
	bltz	a0, 9f
	la	a1, needed_sym1_data_read_msg
	li	a2, needed_sym1_data_read_msg_len
	call	write_stdout
	la	t0, needed_sym1_data_read_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	t0, needed_sym1_runtime_buf
	la	t1, needed_sym1_runtime_addr_slot
	sw	t0, 0(t1)
	la	a1, needed_sym1_runtime_msg
	li	a2, needed_sym1_runtime_msg_len
	call	write_stdout
	la	t0, needed_sym1_runtime_addr_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

apply_needed_relocations:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	sw	zero, 24(sp)
	la	t0, needed_lib_rel_slot
	lw	a0, 0(t0)
	la	t0, needed_lib_relsz_slot
	lw	a1, 0(t0)
	la	t0, needed_lib_relent_slot
	lw	a2, 0(t0)
	call	apply_needed_relocation_table
	lw	t0, 24(sp)
	add	t0, t0, a0
	sw	t0, 24(sp)
	la	t0, needed_lib_pltrel_slot
	lw	t1, 0(t0)
	li	t2, DT_REL
	bne	t1, t2, 1f
	la	t0, needed_lib_jmprel_slot
	lw	a0, 0(t0)
	la	t0, needed_lib_pltrelsz_slot
	lw	a1, 0(t0)
	la	t0, needed_lib_relent_slot
	lw	a2, 0(t0)
	call	apply_needed_relocation_table
	lw	t0, 24(sp)
	add	t0, t0, a0
	sw	t0, 24(sp)
1:
	la	a1, needed_reloc_msg
	li	a2, 39
	call	write_stdout
	lw	a0, 24(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

apply_needed_relocation_table:
	addi	sp, sp, -64
	sw	ra, 60(sp)
	beqz	a0, 9f
	beqz	a1, 9f
	li	t4, 8
	bne	a2, t4, 9f
	la	t0, needed_load_bias_slot
	lw	t5, 0(t0)
	add	a0, a0, t5
	divu	a1, a1, a2
	sw	a0, 56(sp)
	sw	a1, 52(sp)
	sw	t5, 48(sp)
	sw	zero, 44(sp)
1:
	lw	t2, 52(sp)
	beqz	t2, 3f
	lw	t1, 56(sp)
	lw	t3, 0(t1)
	lw	t4, 4(t1)
	lw	t5, 48(sp)
	add	t3, t3, t5
	sw	t3, 40(sp)
	andi	t6, t4, 0xff
	li	t0, R_RISCV_RELATIVE
	beq	t6, t0, 4f
	li	t0, R_RISCV_32
	beq	t6, t0, 5f
	li	t0, R_RISCV_JUMP_SLOT
	beq	t6, t0, 5f
	j	2f
4:
	lw	t0, 0(t3)
	add	t0, t0, t5
	sw	t0, 0(t3)
	lw	t0, 44(sp)
	addi	t0, t0, 1
	sw	t0, 44(sp)
	j	2f
5:
	srli	t4, t4, 8
	beqz	t4, 2f
	la	t0, needed_lib_syment_slot
	lw	t3, 0(t0)
	li	t0, 16
	bltu	t3, t0, 2f
	la	t0, needed_symtab_read_slot
	lw	t5, 0(t0)
	mul	t4, t4, t3
	bgeu	t4, t5, 2f
	la	t0, needed_symtab_buf
	add	t0, t0, t4
	lbu	t6, 12(t0)
	sw	t6, 36(sp)
	lw	t4, 0(t0)
	la	t0, needed_strtab_read_slot
	lw	t5, 0(t0)
	bgeu	t4, t5, 2f
	la	a0, needed_strtab_buf
	add	a0, a0, t4
	sw	a0, 32(sp)
	call	resolve_needed_symbol_table
	la	t0, resolved_symbol_found_slot
	lw	t0, 0(t0)
	bnez	t0, 6f
	lw	t6, 36(sp)
	srli	t6, t6, 4
	li	t0, 2
	bne	t6, t0, 2f
	la	a1, weak_unresolved_msg
	li	a2, weak_unresolved_msg_len
	call	write_stdout
	lw	a1, 32(sp)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	t0, 44(sp)
	addi	t0, t0, 1
	sw	t0, 44(sp)
	j	2f
6:
	la	t0, resolved_symbol_value_slot
	lw	t1, 0(t0)
	lw	t3, 40(sp)
	lw	t0, 0(t3)
	add	t1, t1, t0
	sw	t1, 0(t3)
	lw	t0, 44(sp)
	addi	t0, t0, 1
	sw	t0, 44(sp)
2:
	lw	t1, 56(sp)
	addi	t1, t1, 8
	sw	t1, 56(sp)
	lw	t2, 52(sp)
	addi	t2, t2, -1
	sw	t2, 52(sp)
	j	1b
3:
	lw	a0, 44(sp)
	j	10f
9:
	li	a0, 0
10:
	lw	ra, 60(sp)
	addi	sp, sp, 64
	ret

register_needed_object:
	addi	sp, sp, -32
	sw	ra, 28(sp)
	la	t0, current_needed_obj_index_slot
	lw	t1, 0(t0)
	li	t2, MAX_NEEDED_OBJECTS
	bgeu	t1, t2, 9f
	la	t0, needed_load_base_slot
	lw	t3, 0(t0)
	beqz	t3, 9f
	la	t0, needed_load_bias_slot
	lw	t4, 0(t0)
	la	t0, needed_strtab_read_slot
	lw	t5, 0(t0)
	beqz	t5, 9f
	la	t0, needed_symtab_read_slot
	lw	t6, 0(t0)
	beqz	t6, 9f
	sw	t1, 20(sp)
	sw	t5, 16(sp)
	sw	t6, 12(sp)
	slli	t2, t1, 2
	la	t0, needed_obj_base_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_obj_bias_buf
	add	t0, t0, t2
	sw	t4, 0(t0)
	la	t0, needed_obj_strtab_read_buf
	add	t0, t0, t2
	sw	t5, 0(t0)
	la	t0, needed_obj_symtab_read_buf
	add	t0, t0, t2
	sw	t6, 0(t0)
	la	t0, needed_lib_syment_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_syment_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_symcount_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_symcount_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_gnuhash_runtime_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_gnuhash_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_gnuhash_symoffset_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_gnuhash_symoffset_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_versym_runtime_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_versym_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_verdef_ndx_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_verdef_ndx_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_verdef_hash_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_verdef_hash_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_verdef_name_off_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_verdef_name_off_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_init_slot
	lw	t3, 0(t0)
	beqz	t3, 3f
	la	t0, needed_load_bias_slot
	lw	t4, 0(t0)
	add	t3, t3, t4
3:
	la	t0, needed_obj_init_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_init_array_slot
	lw	t3, 0(t0)
	beqz	t3, 4f
	la	t0, needed_load_bias_slot
	lw	t4, 0(t0)
	add	t3, t3, t4
4:
	la	t0, needed_obj_init_array_buf
	add	t0, t0, t2
	sw	t3, 0(t0)
	la	t0, needed_lib_init_arraysz_slot
	lw	t3, 0(t0)
	la	t0, needed_obj_init_arraysz_buf
	add	t0, t0, t2
	sw	t3, 0(t0)

	la	a0, needed_name_ptr_slot
	lw	a0, 0(a0)
	la	a1, needed_obj_name_pool
	lw	t1, 20(sp)
	li	t3, NEEDED_OBJ_NAME_BYTES
	mul	t4, t1, t3
	add	a1, a1, t4
	li	a2, NEEDED_OBJ_NAME_BYTES
	call	copy_cstr_bounded

	la	a0, needed_strtab_buf
	la	a1, needed_obj_strtab_pool
	lw	t1, 20(sp)
	lw	t5, 16(sp)
	li	t3, NEEDED_OBJ_STRTAB_BYTES
	mul	t4, t1, t3
	add	a1, a1, t4
	mv	a2, t5
	bleu	a2, t3, 1f
	mv	a2, t3
1:
	call	copy_bytes

	la	a0, needed_symtab_buf
	la	a1, needed_obj_symtab_pool
	lw	t1, 20(sp)
	lw	t6, 12(sp)
	li	t3, NEEDED_OBJ_SYMTAB_BYTES
	mul	t4, t1, t3
	add	a1, a1, t4
	mv	a2, t6
	bleu	a2, t3, 2f
	mv	a2, t3
2:
	call	copy_bytes

	lw	t1, 20(sp)
	addi	t1, t1, 1
	la	t0, needed_obj_count_slot
	sw	t1, 0(t0)
	la	a1, needed_object_registered_msg
	li	a2, needed_object_registered_msg_len
	call	write_stdout
	la	t0, needed_obj_count_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
9:
	lw	ra, 28(sp)
	addi	sp, sp, 32
	ret

needed_vaddr_to_file_off:
	la	t0, needed_elf_header
	lw	t1, 28(t0)
	lhu	t2, 44(t0)
	lhu	t3, 42(t0)
	beqz	t1, 9f
	beqz	t2, 9f
	beqz	t3, 9f
	add	t0, t0, t1
1:
	beqz	t2, 9f
	lw	t4, 0(t0)
	li	t5, PT_LOAD
	bne	t4, t5, 2f
	lw	t4, 8(t0)
	bltu	a0, t4, 2f
	lw	t5, 16(t0)
	add	t6, t4, t5
	bgeu	a0, t6, 2f
	lw	t5, 4(t0)
	sub	a0, a0, t4
	add	a0, a0, t5
	li	a1, 1
	ret
2:
	add	t0, t0, t3
	addi	t2, t2, -1
	j	1b
9:
	li	a0, 0
	li	a1, 0
	ret

call_main_init:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, dyn_init_slot
	lw	t0, 0(t0)
	beqz	t0, 1f
	jalr	ra, t0, 0
	la	a1, init_called_msg
	li	a2, init_called_msg_len
	call	write_stdout
1:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

call_needed_initializers:
	addi	sp, sp, -48
	sw	ra, 44(sp)
	la	t0, needed_obj_count_slot
	lw	t1, 0(t0)
	beqz	t1, 9f
	addi	t1, t1, -1
	sw	t1, 40(sp)
1:
	lw	t1, 40(sp)
	bltz	t1, 9f
	slli	t2, t1, 2
	la	t0, needed_obj_bias_buf
	add	t0, t0, t2
	lw	t3, 0(t0)
	sw	t3, 36(sp)
	la	t0, needed_obj_init_buf
	add	t0, t0, t2
	lw	t4, 0(t0)
	beqz	t4, 2f
	sw	t1, 40(sp)
	jalr	ra, t4, 0
	la	a1, needed_init_called_msg
	li	a2, needed_init_called_msg_len
	call	write_stdout
	lw	a0, 40(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
2:
	lw	t1, 40(sp)
	slli	t2, t1, 2
	la	t0, needed_obj_init_array_buf
	add	t0, t0, t2
	lw	t4, 0(t0)
	la	t0, needed_obj_init_arraysz_buf
	add	t0, t0, t2
	lw	t5, 0(t0)
	beqz	t4, 6f
	beqz	t5, 6f
	li	t6, 4
	divu	t5, t5, t6
	sw	t4, 32(sp)
	sw	t5, 28(sp)
	sw	zero, 24(sp)
3:
	lw	t5, 28(sp)
	beqz	t5, 5f
	lw	t4, 32(sp)
	lw	t6, 0(t4)
	addi	t4, t4, 4
	sw	t4, 32(sp)
	addi	t5, t5, -1
	sw	t5, 28(sp)
	jalr	ra, t6, 0
	lw	t0, 24(sp)
	addi	t0, t0, 1
	sw	t0, 24(sp)
	j	3b
5:
	lw	t0, 24(sp)
	beqz	t0, 6f
	la	a1, needed_init_array_called_msg
	li	a2, 45
	call	write_stdout
	lw	a0, 40(sp)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
6:
	lw	t1, 40(sp)
	addi	t1, t1, -1
	sw	t1, 40(sp)
	j	1b
9:
	lw	ra, 44(sp)
	addi	sp, sp, 48
	ret

call_main_init_array:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, dyn_init_array_slot
	lw	s11, 0(t0)
	la	t0, dyn_init_arraysz_slot
	lw	s10, 0(t0)
	beqz	s11, 2f
	beqz	s10, 2f
	li	t0, 4
	divu	s10, s10, t0
	li	s1, 0
1:
	beqz	s10, 3f
	lw	t0, 0(s11)
	addi	s11, s11, 4
	addi	s10, s10, -1
	jalr	ra, t0, 0
	addi	s1, s1, 1
	j	1b
3:
	beqz	s1, 2f
	la	a1, init_array_called_msg
	li	a2, 32
	call	write_stdout
	mv	a0, s1
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
2:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret

write_cstr_stdout:
	beqz	a1, 2f
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	t0, a1
	li	t1, 0
1:
	lbu	t2, 0(t0)
	beqz	t2, 3f
	addi	t0, t0, 1
	addi	t1, t1, 1
	j	1b
3:
	li	a0, 1
	mv	a2, t1
	li	a7, SYS_WRITE
	ecall
	lw	ra, 12(sp)
	addi	sp, sp, 16
2:
	ret

write_hex32_stdout:
	la	t0, hex_buf
	li	t1, 0x30
	sb	t1, 0(t0)
	li	t1, 0x78
	sb	t1, 1(t0)
	addi	t0, t0, 2
	li	t2, 28
	la	t4, hex_digits
1:
	srl	t3, a0, t2
	andi	t3, t3, 0x0f
	add	t5, t4, t3
	lbu	t6, 0(t5)
	sb	t6, 0(t0)
	addi	t0, t0, 1
	addi	t2, t2, -4
	bgez	t2, 1b
	li	a0, 1
	la	a1, hex_buf
	li	a2, 10
	li	a7, SYS_WRITE
	ecall
	ret

	.section .bss, "aw", @nobits
	.balign	16
hex_buf:
	.skip	10
main_bias_slot:
	.word	0
dyn_strtab_slot:
	.word	0
dyn_symtab_slot:
	.word	0
dyn_strsz_slot:
	.word	0
dyn_syment_slot:
	.word	0
dyn_needed_slot:
	.word	0
dyn_needed_count_slot:
	.word	0
dyn_verneed_slot:
	.word	0
dyn_verneednum_slot:
	.word	0
dyn_versym_slot:
	.word	0
main_verneed_file_off_slot:
	.word	0
main_verneed_hash_slot:
	.word	0
main_verneed_other_slot:
	.word	0
main_verneed_name_off_slot:
	.word	0
main_verneed_match_slot:
	.word	0
current_main_sym_versym_slot:
	.word	0
dyn_soname_slot:
	.word	0
dyn_init_slot:
	.word	0
dyn_init_array_slot:
	.word	0
dyn_init_arraysz_slot:
	.word	0
dyn_jmprel_slot:
	.word	0
dyn_pltrelsz_slot:
	.word	0
dyn_pltrel_slot:
	.word	0
dyn_needed_offsets_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
current_needed_obj_index_slot:
	.word	0
needed_name_ptr_slot:
	.word	0
needed_name_loaded_slot:
	.word	0
needed_current_name_buf:
	.skip	NEEDED_OBJ_NAME_BYTES
needed_obj_count_slot:
	.word	0
needed_obj_name_pool:
	.skip	MAX_NEEDED_OBJECTS * NEEDED_OBJ_NAME_BYTES
needed_obj_base_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_bias_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_strtab_read_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_symtab_read_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_syment_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_symcount_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_gnuhash_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_gnuhash_symoffset_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_versym_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_verdef_ndx_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_verdef_hash_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_verdef_name_off_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_init_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_init_array_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_obj_init_arraysz_buf:
	.skip	MAX_NEEDED_OBJECTS * 4
needed_fd_slot:
	.word	0
needed_read_slot:
	.word	0
needed_dynamic_off_slot:
	.word	0
needed_dynamic_vaddr_slot:
	.word	0
needed_dynamic_size_slot:
	.word	0
needed_dynamic_read_slot:
	.word	0
needed_lib_strtab_slot:
	.word	0
needed_lib_strsz_slot:
	.word	0
needed_lib_hash_slot:
	.word	0
needed_lib_gnuhash_slot:
	.word	0
needed_lib_gnuhash_runtime_slot:
	.word	0
needed_lib_gnuhash_symoffset_slot:
	.word	0
needed_lib_versym_slot:
	.word	0
needed_lib_versym_runtime_slot:
	.word	0
needed_lib_verdef_slot:
	.word	0
needed_lib_verdefnum_slot:
	.word	0
needed_lib_verdef_ndx_slot:
	.word	0
needed_lib_verdef_hash_slot:
	.word	0
needed_lib_verdef_name_off_slot:
	.word	0
needed_lib_verneed_slot:
	.word	0
needed_lib_verneednum_slot:
	.word	0
needed_lib_symcount_slot:
	.word	0
needed_lib_symtab_slot:
	.word	0
needed_lib_syment_slot:
	.word	0
needed_lib_soname_slot:
	.word	0
needed_lib_needed_slot:
	.word	0
needed_lib_needed_count_slot:
	.word	0
needed_lib_needed_offsets_buf:
	.skip	MAX_TRANSITIVE_NEEDED * 4
needed_lib_rel_slot:
	.word	0
needed_lib_relsz_slot:
	.word	0
needed_lib_relent_slot:
	.word	0
needed_lib_jmprel_slot:
	.word	0
needed_lib_pltrelsz_slot:
	.word	0
needed_lib_pltrel_slot:
	.word	0
needed_lib_init_slot:
	.word	0
needed_lib_init_array_slot:
	.word	0
needed_lib_init_arraysz_slot:
	.word	0
needed_strtab_off_slot:
	.word	0
needed_strtab_read_slot:
	.word	0
needed_symtab_off_slot:
	.word	0
needed_symtab_read_slot:
	.word	0
needed_sym1_name_off_slot:
	.word	0
needed_sym1_value_slot:
	.word	0
needed_sym1_size_slot:
	.word	0
needed_sym1_file_off_slot:
	.word	0
needed_sym1_data_read_slot:
	.word	0
needed_sym1_runtime_addr_slot:
	.word	0
needed_load_min_vaddr_slot:
	.word	0
needed_load_max_vaddr_slot:
	.word	0
needed_load_count_slot:
	.word	0
needed_load_base_slot:
	.word	0
needed_load_bias_slot:
	.word	0
needed_load_seg_dst_slot:
	.word	0
needed_load_seg_map_slot:
	.word	0
needed_load_seg_read_slot:
	.word	0
resolved_symbol_found_slot:
	.word	0
resolved_symbol_value_slot:
	.word	0
needed_seek_result:
	.skip	8
needed_path_buf:
	.skip	128
	.balign	4
needed_elf_header:
	.skip	256
needed_dynamic_buf:
	.skip	NEEDED_DYNAMIC_BYTES
needed_strtab_buf:
	.skip	NEEDED_OBJ_STRTAB_BYTES
needed_symtab_buf:
	.skip	NEEDED_OBJ_SYMTAB_BYTES
	.balign	4
needed_obj_strtab_pool:
	.skip	MAX_NEEDED_OBJECTS * NEEDED_OBJ_STRTAB_BYTES
	.balign	4
needed_obj_symtab_pool:
	.skip	MAX_NEEDED_OBJECTS * NEEDED_OBJ_SYMTAB_BYTES
needed_sym1_runtime_buf:
	.skip	4
	.balign	4096
needed_load_buf:
	.skip	0x4000
