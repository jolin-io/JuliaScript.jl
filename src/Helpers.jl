module Helpers
export get_cache_name, get_compiled_name, get_cache_path, find_dependencies, change_load_path, split_toplevel_from_main, prefix_lines

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

function get_compiled_name(cache_name)
    "compiled_" * cache_name[length("script_")+1:end]
end

get_cache_path(cache_name) = joinpath(DEPOT_PATH[1], "scripts_cache", cache_name)


find_dependencies(script_content) = find_dependencies(Meta.parseall(script_content))
function find_dependencies(script_expr::Expr)
    exprs = script_expr.args
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




is_toplevel_expr(expr::Expr) = is_toplevel_expr(expr, Val{expr.head}())
is_toplevel_expr(expr, ::Val{:using}) = true
is_toplevel_expr(expr, ::Val{:import}) = true
is_toplevel_expr(expr, ::Val{:abstract}) = true
is_toplevel_expr(expr, ::Val{:const}) = true
is_toplevel_expr(expr, ::Val{:module}) = true
is_toplevel_expr(expr, ::Val{:struct}) = true
is_toplevel_expr(expr, ::Val{:function}) = true
is_toplevel_expr(expr, ::Val{:(=)}) = Meta.isexpr(expr.args[1], :call)  # one liner function
is_toplevel_expr(expr, _) = false
is_toplevel_expr(expr) = false

split_toplevel_from_main(script_content) = split_toplevel_from_main(script_content, Meta.parseall(script_content))
function split_toplevel_from_main(script_content, script_expr::Expr)
    lines = readlines(IOBuffer(script_content); keep=true)
    exprs = script_expr.args
    toplevel = ""
    main = ""
    for (from, expr, to) in zip(exprs[1:2:end], exprs[2:2:end], [exprs[3:2:end]; (;line = length(lines)+1)])
        Meta.isexpr(expr, :call)
        code = join(lines[from.line:to.line-1], "")
        if is_toplevel_expr(expr)
            toplevel *= code
        else
            main *= code
        end
    end
    toplevel, main
end

function prefix_lines(prefix, script_content; skip_first=true)
    apply_prefix(line) = prefix * line
    lines = readlines(IOBuffer(script_content), keep=true)
    if skip_first
        lines[1] * join(apply_prefix.(lines[2:end]), "")
    else
        join(apply_prefix.(lines), "")
    end
end

end  # module