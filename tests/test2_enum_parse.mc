program test2_enum_parse()

type Color = enum
	Red,
	Green,
	Blue
end

type Flags = enum
	FlagA = 1,
	FlagB,
	FlagC = 8
end

type MhExportKind = enum MH_KIND_PROCEDURE = 0,
	MH_KIND_FUNCTION,
	MH_KIND_TYPE,
	MH_KIND_ENUM
end 

begin
end
