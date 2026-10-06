program modc(argc: int, argv: ^char[]): int  // TODO: actually output "array_of_pchar" to main(...)
(**
 * TMod-c 0.26.5.176
 * By M. Scott Reynolds
 * Date 20 February 2026
 *
 * Port to Mod-c started 4 April 2026
 * 30 Apr 2026 - Add command line options.
 * 2 May 2026 - Use TYPE ... STRUCT for command line options.
 * 2 May 2026 - Refactor code into several functions.
 * 30 May 2026 - Add options for generating header file and other stuff.
 * 8 June 2026 - Add debug flag
 * 8 August 2026 - Add quiet flag
 * 3 September 2026 - Refactor for 0.26.5.176
 * 21 September 2026 - Several .mc inputs; each unit a fresh arena
 *)


import size_t 
    from "stddef.h"
import stderr, SEEK_END, SEEK_SET, fclose, fopen, fprintf, fputs, 
    fread, fseek, ftell, perror, printf, FILE, 
    from "stdio.h"
import exit, free, malloc, 
    from "stdlib.h"
import memcmp, memcpy, strcmp, strlen, 
    from "string.h"
import TParser 
    from parser_common
import TParser::init, TParser::parse 
    from parser_main
import NODE_PROGRAM, node_print, Node, 
    from "node.h"
import 
    CodegenTarget, TARGET_C, TARGET_HEADER, TARGET_MH, TARGET_VM, 
    TARGET_WASM, TARGET_JSON
    from codegen_common
import VERSION, VERSION_BASE, BUILD_NUMBER 
    from "version.h"
import InitialContext, codegen_generate, 
    from codegen
import DynBuf, dynbuf_init, dynbuf_append, dynbuf_appendn, dynbuf_append_char,
    dynbuf_free, 
    from dynbuf
import Arena, arena_init, arena_free, 
    from arena
import TSymbolTable 
    from symtab
import semantic_analyze 
    from semantic
import utils_strndup 
    from utils
import codegen_mh_has_exports 
    from codegen_mh


type pchar = ^char
type pFILE = ^FILE
type pNode = ^Node
type pbool = ^bool
type array_of_pchar = ^char[]

// Command line options
type TCommandLine = struct
    show_tokens: bool
    show_info: bool
    show_ast: bool
    show_version: bool
    be_quiet: bool
    debug_enabled: bool
    assert_off: bool
    dbc_off: bool
    generate_c: bool        (* -C seen *)
    generate_h: bool        (* -H seen *)
    generate_mh: bool       (* -M seen *)
    mc_input_file: pchar
    c_output_path: pchar    (* explicit path only; nil = output from unit name *)
    h_output_path: pchar
    mh_output_path: pchar
    output_dir: pchar       (* -d *)
    output_base: pchar      (* -b stem, overrides unit name *)
    mc_input_count: integer
    mc_inputs: array[512] of pchar
end


const MAX_PATH = 4096
const MAX_MC_INPUTS = 512


(* ================================================== *)
(* Some helper functions for dealing with file nmaes. *)
(* ================================================== *)


function ends_with(s: string, suffix: string): bool
begin
    if s == nil or suffix == nil then
        return false
    end
    let slen: size_t = strlen(s)
    let xlen: size_t = strlen(suffix)
    if slen < xlen then
        return false
    end
    return memcmp(s + (slen - xlen), suffix, xlen) == 0
end ends_with


(* Same directory and stem as path, with new_ext (include the dot. e.g. .h"). *)
function path_replace_ext(path: string, new_ext: string): pchar
begin
    var slen: size_t = 0
    var i: size_t = 0
    var stem_len: size_t = 0
    var buf: DynBuf = {0}

    if path == nil or new_ext == nil or path[0] == '\0' then
        return nil
    end

    slen := strlen(path)
    stem_len := slen
    i := slen
    while i > 0 do
        i := i - 1
        if path[i] == '/' or path[i] == '\\' then
            break
        end
        if path[i] == '.' then
            stem_len := i
            break
        end
    end

    dynbuf_init(@buf)
    defer dynbuf_free(@buf)
    dynbuf_appendn(@buf, path, stem_len)
    dynbuf_append(@buf, new_ext)
    return utils_strndup(buf.data, buf.used)
end path_replace_ext


function is_mc_source_path(s: string): bool
begin
    return ends_with(s, ".mc") and s[0] <> '-'
end


function is_c_output_path(s: string): bool
begin
    return ends_with(s, ".c") and s[0] <> '-'
end


function is_h_output_path(s: string): bool
begin
    return ends_with(s, ".h") and s[0] <> '-'
end


function is_mh_output_path(s: string): bool
begin
    return ends_with(s, ".mh") and s[0] <> '-'
end


(*
 * Decide whether the token after -C/-H is an explicit output path.
 * Never consume an .mc path (several inputs: tmodc -C *.mc).
 *)
function is_optional_output_arg(next: string, for_header: bool, for_mh: bool): bool
begin
    if next == nil or next[0] == '\0' or next[0] == '.' or next[0] == '-' then
        return false
    end
    if for_mh then
        if is_mh_output_path(next) then
            return true
        end
    elsif for_header then
        if is_h_output_path(next) then
            return true
        end
    elsif is_c_output_path(next) then
        return true
    end
    if is_mc_source_path(next) then
        return false
    end
    return true
end


(*
 * Return pointer to newly allocated dirname. 
 * Caller responsible for freeing results.
 *)
function path_dirname(path: string): pchar
begin
    var last: integer = -1
    var path_len: size_t = 0
    var n: integer = 0
    var dir: pchar = nil

    if path == nil then
        return nil
    end

    while n < MAX_PATH and path[n] <> '\0' do
        if path[n] == '/' or path[n] == '\\' then
            last := n
        end
        inc(n)
    end

    // No path seperator found.
    if last < 0 then
        return utils_strndup(".", 1)
    end

    // Last path seperator is the first char
    if last == 0 then
        return utils_strndup("/", 1)
    end

    path_len := last as size_t
    dir := malloc(path_len + 1)
    if dir == nil then
        return nil
    end
    memcpy(dir, path, path_len)
    dir[path_len] := '\0'
    return dir
end path_dirname


function build_output_file_path(dir: string, base: string, base_len: size_t, ext: string): pchar
begin
    var buf: DynBuf = {0}
    var dir_len: size_t = 0
    var use_dir: bool = true

    if base == nil or base_len == 0 or ext == nil then 
        return nil
    end

    dynbuf_init(@buf)
    defer dynbuf_free(@buf)

    if dir == nil or dir[0] == '\0' or strcmp(dir, ".") == 0 then
        use_dir := false
    end

    if use_dir then
        dir_len := strlen(dir)
        dynbuf_appendn(@buf, dir, dir_len)
        if dir[dir_len - 1] <> '/' and dir[dir_len - 1] <> '\\' then
            dynbuf_append_char(@buf, '/')
        end
    end

    dynbuf_appendn(@buf, base, base_len)
    dynbuf_append(@buf, ext)
    return utils_strndup(buf.data, buf.used)
end build_output_file_path


function resolve_output_path(input_file: string, unit_name: string, unit_name_len: size_t,
                output_dir_opt: string, output_base_opt: string, ext: string): pchar
begin
    var dir_owned: pchar = nil
    var dir: string = output_dir_opt
    var base: string = unit_name
    var base_len: size_t = unit_name_len

    if output_base_opt <> nil and output_base_opt[0] <> '\0' then
        base := output_base_opt
        base_len := strlen(output_base_opt)
    end

    if dir == nil or dir[0] == '\0' then
        dir_owned := path_dirname(input_file)
        if dir_owned == nil then
            return nil
        end
        dir := dir_owned
    end

    let result: pchar = build_output_file_path(dir, base, base_len, ext)
    free(dir_owned)
    return result
end resolve_output_path


(*
 * Simple command-line option parser.
 * Supports:
 *  -t, --tokens    enable token tracing (lexer debug output)
 *  -h, --help      usage
 *
 * Returns TCommandLine with values or prints usage and exits.
 *)
 function parse_command_line(argc: int, argv: array_of_pchar): TCommandLine
 begin
    var results: TCommandLine
    var i: int = 1

    results.show_tokens := false
    results.show_info := false
    results.show_ast := false
    results.show_version := false
    results.be_quiet := false
    results.debug_enabled := false
    results.assert_off := false
    results.dbc_off := false
    results.generate_c := false
    results.generate_h := false
    results.generate_mh := false
    results.mc_input_file := nil
    results.c_output_path := nil
    results.h_output_path := nil
    results.mh_output_path := nil
    results.output_dir := nil
    results.output_base := nil
    results.mc_input_count := 0

    if argc > 1 then
        while i < argc do
            var arg: pchar = argv[i]

            if strcmp(argv[i], "-h") == 0 or strcmp(argv[i], "--help") == 0 then
                fprintf(stderr, "TMod-c %s (%d)\n", VERSION_BASE, BUILD_NUMBER)
                fprintf(stderr, "Usage: tmodc [options] file.mc ...\n")
                fprintf(stderr, "Options:\n")
                fprintf(stderr, "  -a, --ast        Display the Abstract Syntax Tree with semantic analysis.\n")
                fprintf(stderr, "  -i, --info       Dislay options passed to Mod-c\n")
                fprintf(stderr, "  -t, --tokens     Enable token tracing in AST\n")
                fprintf(stderr, "  -C [file.c]      Generate C and companion .h; default name/dir from PROGRAM/MODULE\n")
                fprintf(stderr, "                   Several .mc: omit [file.c]; use -d for a shared output directory\n")
                fprintf(stderr, "  -H [file.h]      Generate header; default name/dir from PROGRAM/MODULE\n")
                fprintf(stderr, "  -M [file.mh]     Generate modc-mh/1 export table\n")
                fprintf(stderr, "  -d directory     Output directory for auto-named -C/-H files\n")
                fprintf(stderr, "  -b basename      Output base name (stem) for auto-named -C/-H files\n")
                fprintf(stderr, "                   (-b and explicit -C/-H/-M paths are illegal with several inputs)\n")
                fprintf(stderr, "  -q, --quiet      Quiet operation\n")
                fprintf(stderr, "  --debug          Turn on debug statements (default off)\n")
                fprintf(stderr, "  --assert-off     Turn off assert statements (default on)\n")
                fprintf(stderr, "  --dbc-off        Turn off DbC statements (default on)\n")
                fprintf(stderr, "  -v, --version    Display version and exit\n")
                fprintf(stderr, "  -h, --help       Show this help\n")
                fprintf(stderr, "\n")
                fprintf(stderr, "No options given, display AST without semantic analysis.\n")
                exit(1)

            elsif strcmp(arg, "-a") == 0 or strcmp(arg, "--ast") == 0 then      // Display AST
                results.show_ast := true

            elsif strcmp(arg, "--debug") == 0 then
                results.debug_enabled := true

            elsif strcmp(arg, "--assert-off") == 0 then
                results.assert_off := true

            elsif strcmp(arg, "--dbc-off") == 0 then
                results.dbc_off := true

            elsif strcmp(arg, "-q") == 0 or strcmp(arg, "--quiet") == 0 then
                results.be_quiet := true

            elsif strcmp(arg, "-i") == 0 or strcmp(arg, "--info") == 0 then      // show TMod-c current options
                results.show_info := true

            elsif strcmp(arg, "-t") == 0 or strcmp(arg, "--tokens") == 0 then
                results.show_tokens := true

            elsif strcmp(arg, "-v") == 0 or strcmp(arg, "--version") == 0 then
                results.show_version := true

            elsif strcmp(arg, "-C") == 0 then     // C output
                results.generate_c := true
                if i + 1 < argc and is_optional_output_arg(argv[i + 1], false, false) then
                    inc(i)
                    results.c_output_path := argv[i]
                end

            elsif strcmp(arg, "-H") == 0 then     // Definition Header output
                results.generate_h := true
                if i + 1 < argc and is_optional_output_arg(argv[i + 1], true, false) then
                    inc(i)
                    results.h_output_path := argv[i]
                end

            elsif strcmp(arg, "-M") == 0 then       // modc-mh/1 export table
                results.generate_mh := true
                if i + 1 < argc and is_optional_output_arg(argv[i + 1], false, true) then
                    inc(i)
                    results.mh_output_path := argv[i]
                end
            elsif strcmp(arg, "-d") == 0 and i + 1 < argc then
                inc(i)
                results.output_dir := argv[i]

            elsif strcmp(arg, "-b") == 0 and i + 1 < argc then
                inc(i)
                results.output_base := argv[i]

            elsif arg[0] == '-' then
                // Check invalid options before setting input/output file
                // If it made it here, it's an invalid option
                fprintf(stderr, "Mod-c: Error: Invalid option '%s'\n", arg)
                exit(1)

            else
                // INput .mc (or any leftover non-option).
                if results.mc_input_count >= MAX_MC_INPUTS then
                    fprintf(stderr, "Mod-c: Error: too many input files (max %d)\n", MAX_MC_INPUTS)
                    exit(1)
                end
                results.mc_inputs[results.mc_input_count] := arg as pchar
                if results.mc_input_file == nil then
                    results.mc_input_file := arg as pchar
                end
                inc(results.mc_input_count)

            end

            inc(i)
        end
    end

    return results
end parse_command_line


(*
 * Get and return the size of a file.
 * @param fp: pFILE	= pointer to an already open FILE
 * @return: integer	= size of the file. 
 *)
function get_file_size(fp: pFILE): size_t
begin
    let file_pos: long = ftell(fp)
    if file_pos < 0 then
        return 0        // error indicator
    end

    if fseek(fp, 0, SEEK_END) <> 0 then
        return 0
    end
    let file_end: long = ftell(fp)

    fseek(fp, file_pos, SEEK_SET)       // restore position

    if file_end < 0 then
        return 0
    end
    return file_end as size_t
end get_file_size


(**
 * Open input file, allocate space, read source, close output file. 
 * @param: input_file = Name of input file to read.
 * @return: Allocated pointer to source if successful. Nil if not successful.
 * Caller owns source.
 *)
 function allocate_source_file(input_file: pchar): pchar
 begin
    var source: pchar = nil     // Input source

    let fp: pFILE = fopen(input_file, "r")
    if fp == nil then
        perror("ERROR: modc.allocate_source_file: Cannot open input file")
    else
        defer fclose(fp)
        let fsize: size_t = get_file_size(fp)

        if fsize == 0 and ftell(fp) <> 0 then       // distinguish empty file vs error
            perror("ERROR: modc.allocate_source_file: Cannot determine file size")
        else
            // Allocate space for file source    
            source := malloc(fsize + 1)
            if source == nil then
                perror("ERROR: modc.allocate_source_file: Memory allocation failed")
            else
                // Read in the file into source buffer.
                fread(source, 1, fsize, fp)
                source[fsize] := '\0'
            end
        end
    end
    return source
end allocate_source_file


(**
 * Generate code from AST.
 * @param context = context with ast, debug_enabled, and target previous set.
 * @param file_name = name of output file.
 * @param quiet = quiet operation
 * @ return: Return 0 on success. > 0 on error.
 *)
function generate_from_ast(context: InitialContext, file_name: pchar, quiet: bool): int
begin
    var return_code: int = 0
    var out_buffer: DynBuf = {0}

    // Initialize Dynamic output buffer
    dynbuf_init(@out_buffer);
    defer dynbuf_free(@out_buffer)

    // Generate code to output buffer.
    context.out := @out_buffer
    codegen_generate(context)

    // context doesn't need to point to out_buffer anymore
    context.out := nil

    // Write to output file.
    if file_name == nil then
        perror("ERROR: modc.generate_from_ast: output file_name not specified")
        return_code += 1
    else
        let out_file: pFILE = fopen(file_name, "w")
        if out_file == nil then
            perror("ERROR: modc.generate_from_ast: Cannot open out_file")
            return_code += 1
        else
            fputs(out_buffer.data, out_file)
            fclose(out_file)
            if not quiet then
                printf("Code generation complete: %s\n", file_name)
            end
        end
    end

    return return_code
end


(**
 * Process one unit at a time.
 *)
function process_one_unit(options: TCommandLine, input_file: pchar): int
begin
    var arena: Arena            // Memory arena.
    var p: TParser              // Parser
    var source: pchar = nil     // Input source file,
    var ast: pNode = nil        // Pointer to AST.
    var return_code: int = 0

    // Open input file, read in source, close input file
    source := allocate_source_file(input_file)
    if source <> nil then
        defer free(source)

        // Initialize arena
        arena_init(@arena, 1024 * 1024)
        defer arena_free(@arena)

        // Initialize parser
        TParser::init(p, @arena, source, nil)
        // defer parser_free(@p)        // TODO: ??

        // Pass flags to parser/lexer
        p.show_tokens := options.show_tokens
        p.debug_enabled := options.debug_enabled

        // Build the Abstract Syntax Tree
        ast := TParser::parse(p)

        if ast == nil then
            perror("ERROR: main: TParser::parse returned NIL\n")
            return_code += 1
        else
            // defer node_free(ast)     TODO: ??

            // Any code options passed?
            if options.generate_c or options.generate_h or options.generate_mh then
                var context: InitialContext
                var c_file: pchar = options.c_output_path
                var h_file: pchar = options.h_output_path
                var mh_file: pchar = options.mh_output_path
                var c_auto: pchar = nil
                var h_auto: pchar = nil
                var mh_auto: pchar = nil
                var unit_name: string = nil
                var unit_len: size_t = 0

                // Perform semantic analysis
                semantic_analyze(@arena, ast, options.mc_input_file)

                unit_name := ast.program_decl.name
                unit_len := ast.program_decl.name_len

                // Setup context.
                context.ast := ast
                context.debug_enabled := options.debug_enabled
                context.assert_off := options.assert_off
                context.dbc_off := options.dbc_off

                // Setup output file paths
                if options.generate_c and c_file == nil then
                    c_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
                        options.output_dir, options.output_base, ".c")
                    c_file := c_auto
                end
                if options.generate_c and h_file == nil then
                    if c_file <> nil then
                        h_auto := path_replace_ext(c_file, ".h")
                        h_file := h_auto
                    end
                end
                if options.generate_h and h_file == nil then
                    h_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
                        options.output_dir, options.output_base, ".h")
                    h_file := h_auto
                end
                if (options.generate_mh or (options.generate_c and codegen_mh_has_exports(ast))) and
                        mh_file == nil then
                    mh_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
                        options.output_dir, options.output_base, ".mh")
                    mh_file := mh_auto
                end

                // Generate C code.
                if options.generate_c then
                    if c_file == nil then
                        fprintf(stderr, "ERROR: could not determine C output path\n")
                        return_code += 1
                    else
                        context.target := TARGET_C
                        return_code += generate_from_ast(context, c_file, options.be_quiet)
                    end
                end

                // Generate HEADER (.h) code.
                if options.generate_h or options.generate_c then
                    if h_file == nil then
                        fprintf(stderr, "ERROR: could not determine header output path\n")
                        return_code += 1
                    else
                        context.target := TARGET_HEADER
                        return_code += generate_from_ast(context, h_file, options.be_quiet)
                    end
                end

                // Generate .mh export table
                if options.generate_mh or (options.generate_c and codegen_mh_has_exports(ast)) then
                    if mh_file == nil then
                        fprintf(stderr, "ERROR: could not determine .mh output path\n")
                        return_code += 1
                    else
                        context.target := TARGET_MH
                        return_code += generate_from_ast(context, mh_file, options.be_quiet)
                    end
                end

                if c_auto <> nil then
                    free(c_auto)
                end
                if h_auto <> nil then
                    free(h_auto)
                end
                if mh_auto <> nil then
                    free(mh_auto)
                end
            elsif options.show_ast then
                // Perform semantic analysis and display AST
                // printf("0000:0000 %s: ", options.mc_input_file)
                // printf("Abstract Syntax Tree with Semantic Analysis\n")
                semantic_analyze(@arena, ast, options.mc_input_file)
                node_print(ast, 0)
            else
                // Default, show AST without semantic_analysis
                // printf("0000:0000 %s: ", options.mc_input_file)
                // printf("Abstract Syntax Tree\n")
                node_print(ast, 0)
            end
        end
    end
    return return_code
end process_one_unit


(**
 * Main entry point
 *)
begin
    // var arena: Arena            // Memory arena.
    // var p: TParser              // Parser
    // var source: pchar = nil     // Input source file,
    // var ast: pNode = nil        // Pointer to AST.
    var options: TCommandLine   // command line options
    var return_code: int = 0
    var i: integer = 0

    options := parse_command_line(argc, argv)

    // Display options selected.
    if options.show_info then
        printf("show_tokens = %d", options.show_tokens)
        printf(", show_ast = %d", options.show_ast)
        if options.mc_input_file <> nil then
            printf(", mc_input_file = %s", options.mc_input_file)
        end
        printf(", mc_input_count = %d", options.mc_input_count)

        printf(", generate_c = %d", options.generate_c)
        if options.c_output_path <> nil then
            printf(", c_output_path = %s", options.c_output_path)
        end

        printf(", generate_h = %d", options.generate_h)
        if options.h_output_path <> nil then
            printf(", h_output_path = %s", options.h_output_path)
        end
        printf("\n")
    end

    if options.show_version then
        fprintf(stderr, "TMod-c %s (%d)\n", VERSION_BASE, BUILD_NUMBER)
        fprintf(stderr, "VERSION_BASE: %s\n", VERSION_BASE)
        fprintf(stderr, "BUILD_NUMBER: %d\n", BUILD_NUMBER)
        fprintf(stderr, "INSTALLED: %s\n", argv[0])
        return 1
    end

    if options.mc_input_count <= 0 then
        fprintf(stderr, "Usage: tmodc [options] file.mc ...\n")
        fprintf(stderr, "Try '%s --help' for more information.\n", argv[0])
        return 1
    end

    if options.mc_input_count > 1 then
        if options.c_output_path <> nil or options.h_output_path <> nil or
                options.mh_output_path <> nil then
            fprintf(stderr, "ERROR: several inputs: do not pass -C/-H/-M file paths; use defaults or -d\n")
            return 1
        end
        if options.output_base <> nil then
            fprintf(stderr, "ERROR: several inputs: -b is not allowed\n")
            return 1
        end
    end

    i := 0
    while i < options.mc_input_count do
        return_code := process_one_unit(options, options.mc_inputs[i])
        if return_code <> 0 then
            return return_code
        end
        inc(i)
    end

    // // Open input file, read in source, close input file
    // source := allocate_source_file(options.mc_input_file)
    // if source <> nil then
    //     defer free(source)

    //     // Initialize arena
    //     arena_init(@arena, 1024 * 1024)
    //     defer arena_free(@arena)

    //     // Initialize parser
    //     TParser::init(p, @arena, source, nil)
    //     // defer parser_free(@p)        // TODO: ??

    //     // Pass flags to parser/lexer
    //     p.show_tokens := options.show_tokens
    //     p.debug_enabled := options.debug_enabled

    //     // Build the Abstract Syntax Tree
    //     ast := TParser::parse(p)

    //     if ast == nil then
    //         perror("ERROR: main: TParser::parse returned NIL\n")
    //         return_code += 1
    //     else
    //         // defer node_free(ast)     TODO: ??

    //         // Any code options passed?
    //         if options.generate_c or options.generate_h or options.generate_mh then
    //             var context: InitialContext
    //             var c_file: pchar = options.c_output_path
    //             var h_file: pchar = options.h_output_path
    //             var mh_file: pchar = options.mh_output_path
    //             var c_auto: pchar = nil
    //             var h_auto: pchar = nil
    //             var mh_auto: pchar = nil
    //             var unit_name: string = nil
    //             var unit_len: size_t = 0

    //             // Perform semantic analysis
    //             semantic_analyze(@arena, ast, options.mc_input_file)

    //             unit_name := ast.program_decl.name
    //             unit_len := ast.program_decl.name_len

    //             // Setup context.
    //             context.ast := ast
    //             context.debug_enabled := options.debug_enabled
    //             context.assert_off := options.assert_off
    //             context.dbc_off := options.dbc_off

    //             // Setup output file paths
    //             if options.generate_c and c_file == nil then
    //                 c_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
    //                     options.output_dir, options.output_base, ".c")
    //                 c_file := c_auto
    //             end
    //             if options.generate_c and h_file == nil then
    //                 if c_file <> nil then
    //                     h_auto := path_replace_ext(c_file, ".h")
    //                     h_file := h_auto
    //                 end
    //             end
    //             if options.generate_h and h_file == nil then
    //                 h_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
    //                     options.output_dir, options.output_base, ".h")
    //                 h_file := h_auto
    //             end
    //             if (options.generate_mh or (options.generate_c and codegen_mh_has_exports(ast))) and
    //                     mh_file == nil then
    //                 mh_auto := resolve_output_path(options.mc_input_file, unit_name, unit_len,
    //                     options.output_dir, options.output_base, ".mh")
    //                 mh_file := mh_auto
    //             end

    //             // Generate C code.
    //             if options.generate_c then
    //                 if c_file == nil then
    //                     fprintf(stderr, "ERROR: could not determine C output path\n")
    //                     return_code += 1
    //                 else
    //                     context.target := TARGET_C
    //                     return_code += generate_from_ast(context, c_file, options.be_quiet)
    //                 end
    //             end

    //             // Generate HEADER (.h) code.
    //             if options.generate_h or options.generate_c then
    //                 if h_file == nil then
    //                     fprintf(stderr, "ERROR: could not determine header output path\n")
    //                     return_code += 1
    //                 else
    //                     context.target := TARGET_HEADER
    //                     return_code += generate_from_ast(context, h_file, options.be_quiet)
    //                 end
    //             end

    //             // Generate .mh export table
    //             if options.generate_mh or (options.generate_c and codegen_mh_has_exports(ast)) then
    //                 if mh_file == nil then
    //                     fprintf(stderr, "ERROR: could not determine .mh output path\n")
    //                     return_code += 1
    //                 else
    //                     context.target := TARGET_MH
    //                     return_code += generate_from_ast(context, mh_file, options.be_quiet)
    //                 end
    //             end

    //             if c_auto <> nil then
    //                 free(c_auto)
    //             end
    //             if h_auto <> nil then
    //                 free(h_auto)
    //             end
    //             if mh_auto <> nil then
    //                 free(mh_auto)
    //             end
    //         elsif options.show_ast then
    //             // Perform semantic analysis and display AST
    //             // printf("0000:0000 %s: ", options.mc_input_file)
    //             // printf("Abstract Syntax Tree with Semantic Analysis\n")
    //             semantic_analyze(@arena, ast, options.mc_input_file)
    //             node_print(ast, 0)
    //         else
    //             // Default, show AST without semantic_analysis
    //             // printf("0000:0000 %s: ", options.mc_input_file)
    //             // printf("Abstract Syntax Tree\n")
    //             node_print(ast, 0)
    //         end
    //     end
    // end

    return return_code
end modc
