using JuliaScript
using Test

if Sys.islinux()
    @testset "JuliaScript.jl" begin

        exe_file = abspath(joinpath(@__DIR__, "..", "bin", "juliascript"))
        script_file = joinpath(@__DIR__, "testscript.jl")
        cache_name = JuliaScript.Helpers.get_cache_name(script_file)
        cache_path = JuliaScript.Helpers.get_cache_path(cache_name)

        # always start with clean caching directory
        rm(cache_path, recursive=true, force=true)

        target = strip("""
        9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
        hello
        world
        arg1 = "42"
        """)

        # run first time
        @test readchomp(`bash $exe_file $script_file 42`) == target

        # run second time
        @test readchomp(`bash $exe_file $script_file 42`) == target

        # packagecompile
        @test readchomp(`bash $exe_file packagecompile $script_file`) == target

        # run again
        @test readchomp(`bash $exe_file $script_file 42`) == target

        # TODO compare timings? they should always be in order kind of
    end
end