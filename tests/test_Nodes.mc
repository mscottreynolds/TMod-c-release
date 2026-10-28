program Nodes()

(**
 * Testing Node that extends Object.
 *)


import printf from "stdio.h"
import malloc, calloc, free from "stdlib.h"
import size_t from "stddef.h"


type TObject = struct
	object_size: size_t
	object_name: const ^char
end
type Object = ^TObject

type TNodeSansObject = struct
	capacity: size_t
	count: size_t
	data: ^byte
end
type NodeSansObject = ^TNodeSansObject

type TNode = struct extends TObject
	capacity: size_t
	count: size_t
	data: ^byte
end
type Node = ^TNode


type Mallinfo2 = struct
	arena: size_t
	ordblks: size_t
	smblks: size_t
	hblks:size_t
	hblkhd: size_t
	usmblks: size_t
	fsmblks: size_t
	wordblks: size_t
	fordblks: size_t
	keepcost: size_t
end

extern function mallinfo2(): Mallinfo2


(* Object::Object acts as a constructor *)
function Object::Object(name: const ^char, size: size_t): Object
begin
	require name <> nil and size >= sizeof(TObject)

	var object: Object = malloc(size)

	assert object <> nil
	object.object_size := size
	object.object_name := name
	return object
end


procedure Object::free(var self: Object)
begin
	self.object_name := nil
	self.object_size := 0
	free(self)
	self := nil
end


(* Node::Node acts as a constructor *)
function Node::Node(capacity: size_t): Node
begin
	require capacity > 0

	var node: Node = Object("TNode", sizeof(TNode)) as Node
	assert node <> nil
	node.capacity := capacity
	node.count := 0
	node.data := malloc(capacity)
	assert node.data <> nil
	return node
end


procedure Node::free(var self: Node)
begin
	if self <> nil then
		var object: Object = self as Object
		if self.data <> nil then
			free(self.data)
		end
		self.data := nil
		self.capacity := 0
		self.count := 0
		// Object::free(self)	<-- this form isn't valid. Requires actual designator for VAR/REF
		object.free() 			// Use this form with VAR/REF.
		self := nil
	end
	ensure self == nil
end


(** test Node and Object. *)
begin
	var node: Node = nil

	printf("Running...\n")

	printf("wordblks: %zu\n", mallinfo2().wordblks)

	node := Node(50)

	printf("wordblks: %zu\n", mallinfo2().wordblks)

	printf("node.object_name = %s\n", node.object_name)
	printf("node.object_size = %d\n", node.object_size as integer)
	printf("sizeof(TObject) = %d\n", sizeof(TObject))
	printf("sizeof(TNodeSansObject) = %d\n", sizeof(TNodeSansObject))
	printf("sizeof(TNode) = %d\n", sizeof(TNode))
	printf("node.capacity = %d\n", node.capacity as integer)

	printf("wordblks: %zu\n", mallinfo2().wordblks)

	node.free()

	printf("wordblks: %zu\n", mallinfo2().wordblks)
end
