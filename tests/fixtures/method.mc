module method()


export type T = struct 
	x: integer
end


export function T::make(x: integer): T 				// static: first formal <> T
begin
	var t: T
	t.x := x
	return t
end


export procedure T::set(var self: T, x: integer) 	// instance
begin
	self.x := x
end


export function T::get(var self: T): integer
begin
	return self.x
end


begin
end
