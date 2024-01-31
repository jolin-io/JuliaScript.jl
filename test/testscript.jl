function hello()
    println("hello")
end
abstract type MyType end
mutable struct MyStruct end

const world = "world"
using SHA
println(bytes2hex(sha256("test")))
hello()
println(world)
arg1 = ARGS[1]
@show arg1
