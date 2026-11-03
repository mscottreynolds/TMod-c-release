program test3_type_ptr_cycle()

type A = ^B
type B = ^A

begin
end test3_type_ptr_cycle

