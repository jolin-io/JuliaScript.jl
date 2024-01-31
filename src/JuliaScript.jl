module JuliaScript

import Pkg
import PackageCompiler
using UUIDs: uuid4

include("Helpers.jl")
using .Helpers


function create_app()
    cache_name = get(ENV, "JULIASCRIPT_CACHE_NAME") do 
        script_path = abspath(expanduser(ARGS[1]))
        assert_isfile(script_path)
        get_cache_name(script_path)
    end
    cache_path = get(ENV, "JULIASCRIPT_CACHE_PATH", get_cache_path(cache_name))

    precompile_statements_file = joinpath(cache_path, "src", "precompile_statements.jl") 
    if !isfile(precompile_statements_file) || filesize(precompile_statements_file) <= 0
        @error "Please run juliascript once normally, so that the precompile statements needed for PackageCompiler are constructed."
        exit(1)
    end

    compiled_name = get_compiled_name(cache_name)
    compiled_path = get_cache_path(compiled_name)
    PackageCompiler.create_app(cache_path, compiled_path; incremental=true, cpu_target="native", precompile_statements_file)
end


function create_sysimage()
    cache_name = get(ENV, "JULIASCRIPT_CACHE_NAME") do 
        script_path = abspath(expanduser(ARGS[1]))
        assert_isfile(script_path)
        get_cache_name(script_path)
    end
    cache_path = get(ENV, "JULIASCRIPT_CACHE_PATH", get_cache_path(cache_name))

    precompile_statements_file = joinpath(cache_path, "src", "precompile_statements.jl") 
    if !isfile(precompile_statements_file) || filesize(precompile_statements_file) <= 0
        @error "Please run juliascript once normally, so that the precompile statements needed for PackageCompiler are constructed."
        exit(1)
    end

    Pkg.activate(cache_path)
    PackageCompiler.create_sysimage([cache_name]; sysimage_path=joinpath(cache_path, "sysimage.so"), cpu_target="native", precompile_statements_file)
end


function julia_main()::Cint
    if length(ARGS) < 1
        @error "Please provide the path to the julia script as an argument." PROGRAM_FILE=PROGRAM_FILE
        exit(1)
    end
    script_path = abspath(expanduser(ARGS[1]))
    assert_isfile(script_path)
    run_script(script_path, ARGS[2:end])
    return 0
end


function assert_isfile(script_path)
    if !isfile(script_path)
        @error "The given file does not exist"
        exit(1)
    end
end

function run_script(script_path, commandline_args)
    script_content = read(script_path, String)  # readchomp is bad here. It will lead different hashes because of stripped last newline
    cache_name = get(ENV, "JULIASCRIPT_CACHE_NAME", get_cache_name(script_path, script_content))
    cache_path = get(ENV, "JULIASCRIPT_CACHE_PATH", get_cache_path(cache_name))
    all_kwargs = (; script_path, script_content, cache_name, cache_path)

    if !isdir(cache_path)
        # first run - tracks precompile statements
        create_script_package(; all_kwargs...)

        if success(run(`julia -q --project="$cache_path" -e "import var\"$cache_name\"; var\"$cache_name\".julia_main()" --trace-compile="$cache_path/src/precompile_statements.jl" -- $commandline_args`))
            # now we recreated the precompilation statements, they now need to be included into the main module to retrigger precompilation
            # it turns out that precompilation will not be retriggered if our helper precompile.jl script was already there before.
            # it really needs a change in a module file which is `include`ed
            add_precompilation(; all_kwargs...)
        else
            # if the very first run failed, this should not be counted as a valid load_path_setup_code
            # hence we delete the cache folder again in order to retrigger the setup on the next run (with possibly different script parameters)
            rm(cache_path, force=true, recursive=true)
        end
    else
        # normal run
        # (This is actually quite expensive for small julia scripts, as the julia startup time is significant. Hence we do the check already on the bash side so that this is actually redundant.)
        run(`julia -q --project="$cache_path" -e "import var\"$cache_name\"; var\"$cache_name\".julia_main()" $commandline_args`)
    end
end

function create_script_package(; script_path, script_content, cache_name, cache_path, rest...)
    mkpath(cache_path)

    write(joinpath(cache_path, "Project.toml"), """
    name = "$cache_name"
    uuid = "$(uuid4())"
    authors = ["automatically created by JuliaScript.jl"]
    version = "0.0.0"
    """)

    # create module (without precompilation)
    script_expr = Meta.parseall(script_content)
    dependencies = union(find_dependencies(script_expr), ["PrecompileTools"])
    toplevel, main = split_toplevel_from_main(script_content, script_expr)

    mkpath(joinpath(cache_path, "src"))
    write(joinpath(cache_path, "src", "$cache_name.jl"), """
    module var"$cache_name"
        __precompile__(false)
        $(prefix_lines("    ", toplevel))
        
        function julia_main()::Cint
            $(prefix_lines("        ", main))
            return 0
        end
    end
    """)

    # add and precompile dependencies (silently)
    change_load_path(cache_path) do
        Pkg.add(dependencies, io=devnull)
        Pkg.precompile(io=devnull)
    end
end

function add_precompilation(; script_path, script_content, cache_name, cache_path, rest...)
    script_expr = Meta.parseall(script_content)
    dependencies = union(find_dependencies(script_expr), ["PrecompileTools"])
    toplevel, main = split_toplevel_from_main(script_content, script_expr)

    # this generic code automatically loads a src/precompile_statments.jl file if it exists
    cp(joinpath(@__DIR__, "precompile.jl"), joinpath(cache_path, "src", "precompile.jl"))

    write(joinpath(cache_path, "src", "$cache_name.jl"), """
    module var"$cache_name"
        import PrecompileTools
        PrecompileTools.@recompile_invalidations import $(join(dependencies, ", "))
        
        $(prefix_lines("    ", toplevel))
            
        function julia_main()::Cint
            $(prefix_lines("        ", main))
            return 0
        end

        # Precompilation via actual run
        include("precompile.jl")

        # alternatively one might think of using PrecompileTools,
        # the key problem with this is that print output is somewhere hidden inside precompilation output 
        # @compile_workload julia_main()
    end
    """)
end



include("precompile.jl")

end  # module
