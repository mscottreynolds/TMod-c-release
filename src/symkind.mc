module symkind()

(**
 * symkind.mc - Symbol classification for semantic analysis.
 * Hand-maintained until Mod-C ENUM syntax can own this definition.
 * Port target: export type SymbolKind = enum ... end in tsymbol.mc (or symkind.mc)
 *)


export type SymbolKind = enum
	SYM_KIND_UNKNOWN = 0,
	SYM_KIND_TYPE,
	SYM_KIND_CONST,
	SYM_KIND_LET,
	SYM_KIND_VAR,
	SYM_KIND_PARAM,
	SYM_KIND_RECEIVER,
	SYM_KIND_PROC,
	SYM_KIND_FUNC,
	SYM_KIND_STRUCT,
	SYM_KIND_FIELD,
	SYM_KIND_IMPORT,
end


begin
end symkind

