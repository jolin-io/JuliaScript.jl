module JuliaScript

import Pkg
using UUIDs: uuid4

include("Helpers.jl")
using .Helpers

function julia_main()::Cint
    if length(ARGS) < 1
        @error "Please provide the path to the julia script as an argument." PROGRAM_FILE=PROGRAM_FILE
        exit(1)
    end
    script_path = ARGS[1]
    assert_isfile(script_path)
    script_path = abspath(expanduser(script_path))
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

        # the first time we just import the script without calling main(), because the precompilation will already run the script.
        if success(run(`julia --project="$cache_path" -e "import var\"$cache_name\""`))

        # if success(run(`julia --project="$cache_path" -e "import var\"$cache_name\"; var\"$cache_name\".main()" --trace-compile="$cache_path/src/precompile_statements.jl" $commandline_args`))
        #     # now we recreated the precompilation statements, they now need to be included into the main module to retrigger precompilation
        #     # it turns out that precompilation will not be retriggered if our helper precompile.jl script was already there before.
        #     # it really needs a change in a module file which is `include`ed
        #     add_precompilation(; all_kwargs...)
        #     # the added precompilation will automatically be precompiled on the next run but for a better user experience we do the precompilation already here
        #     # precompilation needs the correct packages to be on the load-path, hence we need to start another julia process
        #     run(`julia --project="$cache_path" -e "import var\"$cache_name\""`)
        else
            # if the very first run failed, this should not be counted as a valid load_path_setup_code
            # hence we delete the cache folder again in order to retrigger the setup on the next run (with possibly different script parameters)
            rm(cache_path, force=true, recursive=true)
        end
    else
        # normal run
        # (This is actually quite expensive for small julia scripts, as the julia startup time is significant. Hence we do the check already on the bash side so that this is actually redundant.)
        run(`julia --project="$cache_path" -e "import var\"$cache_name\"; var\"$cache_name\".julia_main()" $commandline_args`)
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
    dependencies = union(find_dependencies(script_content), ["PrecompileTools"])
    mkpath(joinpath(cache_path, "src"))
    write(joinpath(cache_path, "src", "$cache_name.jl"), """
    module var"$cache_name"
        import PrecompileTools
        PrecompileTools.@recompile_invalidations import $(join(dependencies, ", "))
        
        function julia_main()::Cint
            include("$script_path")
            return 0
        end

        # precompilation will run the script the first time
        PrecompileTools.@compile_workload julia_main()
    end
    """)

    # add dependencies
    change_load_path(cache_path) do
        @show dependencies
        if length(dependencies) >= 1
            Pkg.add(dependencies)
            Pkg.build(dependencies)
            # Pkg.precompile()
        end
    end
end

# function add_precompilation(; script_path, script_content, cache_name, cache_path, rest...)
#     dependencies = find_dependencies(script_content)

#     # this generic code automatically loads a src/precompile_statments.jl file if it exists
#     cp(joinpath(@__DIR__, "precompile.jl"), joinpath(cache_path, "src", "precompile.jl"))

#     write(joinpath(cache_path, "src", "$cache_name.jl"), """
#     module var"$cache_name"
#         import $(join(dependencies, ", "))
#         function main()
#             include("$script_path")
#         end

#         @compile_workload main()

#         # Precompilation via actual run
#         # include("precompile.jl")

#         # alternatively one might think of using PrecompileTools,
#         # however it also runs the script.
#         # Maybe the script needs valid parameters to be run, which
#         # will only be available on the first valid run of the script.
#         # @compile_workload main()
#     end
#     """)
# end

include("precompile.jl")

end  # module
