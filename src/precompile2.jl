# adapted from PackageCompiler to precompile arbitrary precompile statements
module PrecompileStagingArea

    # many precompile statements refer to dependend modules
    # luckily we can make them available manually, without adding them explicitly as
    # dependencies to Project.toml
    for (_pkgid, _mod) in Base.loaded_modules
        if !(_pkgid.name in ("Main", "Core", "Base"))
            @eval const $(Symbol(_mod)) = $_mod
        end
    end

    precompile_files = ["$(@__DIR__)/precompile_statements.jl"]

    for file in precompile_files
        isfile(file) || continue
        for statement in eachline(file)
            try
                # println(statement)
                # This is taken from https://github.com/JuliaLang/julia/blob/2c9e051c460dd9700e6814c8e49cc1f119ed8b41/contrib/generate_precompile.jl#L375-L393
                ps = Meta.parse(statement)
                Meta.isexpr(ps, :call) || continue
                popfirst!(ps.args) # precompile(...)
                ps.head = :tuple
                l = ps.args[end]
                if (Meta.isexpr(l, :tuple) || Meta.isexpr(l, :curly)) && length(l.args) > 0 # Tuple{...} or (...)
                    # XXX: precompile doesn't currently handle overloaded Vararg arguments very well.
                    # Replacing N with a large number works around it.
                    l = l.args[end]
                    if Meta.isexpr(l, :curly) && length(l.args) == 2 && l.args[1] === :Vararg # Vararg{T}
                        push!(l.args, 100) # form Vararg{T, 100} instead
                    end
                end
                # println(ps)
                ps = Core.eval(PrecompileStagingArea, ps)
                # XXX: precompile doesn't currently handle overloaded nospecialize arguments very well.
                # Skipping them avoids the warning.
                ms = length(ps) == 1 ? Base._methods_by_ftype(ps[1], 1, Base.get_world_counter()) : Base.methods(ps...)
                ms isa Vector || continue
                precompile(ps...)
            catch e
                # See julia issue #28808
                @debug "failed to execute $statement"
            end
        end
    end
end