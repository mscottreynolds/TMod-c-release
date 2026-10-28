program test3_byref_cast()

type TObject = struct
	n: integer
end
type Object = ^TObject

type TNode = struct extends TObject
	m: integer
end
type Node = ^TNode

procedure Object::free(var self: Object)
begin
	self := nil
end

procedure Node::free(var self: Node)
begin
	Object::free(self as Object)
end

begin
end
