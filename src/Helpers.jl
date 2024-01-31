module Helpers
export get_cache_name, get_cache_path, find_dependencies, change_load_path

using SHA: sha256

function myhash(script_content)
    return script_content |> sha256 |> bytes2hex
end

function get_cache_name(script_path)
    content = readchomp(script_path)
    get_cache_name(script_path, content)
end

function get_cache_name(script_path, script_content)
    hash = myhash(script_content)
    script_name = basename(script_path)
    if endswith(script_name, ".jl") 
        script_name = script_name[1:end-3]
    end
    return "script_$(script_name)_$(hash)"
end

get_cache_path(cache_name) = joinpath(DEPOT_PATH[1], "scripts_cache", cache_name)


function find_dependencies(julia_text)
    exprs = Meta.parse("begin\n$julia_text\nend").args
    package_names = String[]
    for expr in exprs
        Meta.isexpr(expr, (:import, :using)) && length(expr.args) >= 1 || continue
        # collect module `.` expressions
        modules_expr = if Meta.isexpr(expr.args[1], :(:)) && Meta.isexpr(expr.args[1].args[1], :.)
            # importing specific fields from module - we are only interested in the module name
            [expr.args[1].args[1]]
        elseif all(e -> Meta.isexpr(e, :.), expr.args)
            expr.args
        end

        modules_root_symbols = [String(mod.args[1]) for mod in modules_expr if length(mod.args) >= 1]
        append!(package_names, modules_root_symbols)
    end
    return package_names
end

function change_load_path(run, temporary_path)
    old_LP = LOAD_PATH[:]
    old_AP = Base.ACTIVE_PROJECT[]

    new_LP = ["@", "@stdlib"]
    new_AP = temporary_path
    copy!(LOAD_PATH, new_LP)
    Base.ACTIVE_PROJECT[] = new_AP

    try
        run()
    finally
        # revert LOAD_PATH
        copy!(LOAD_PATH, old_LP)
        Base.ACTIVE_PROJECT[] = old_AP
    end
end

end  # module