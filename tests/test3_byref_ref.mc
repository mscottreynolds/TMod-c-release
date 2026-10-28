program test3_byref_ref()

type TObject = struct
	n: integer
end
type Object = ^TObject

type TNode = struct extends TObject
	m: integer
end
type Node = ^TNode

procedure Object::free(ref self: Object)
begin
	self.n := 0
end

procedure Node::free(var self: Node)
begin
	Object::free(self as Object)
end

begin
end

