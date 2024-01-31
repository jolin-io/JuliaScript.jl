module PrecompileStagingArea

    for (_pkgid, _mod) in Base.loaded_modules
        if !(_pkgid.name in ("Main", "Core", "Base"))
            @eval const $(Symbol(_mod)) = $_mod
        end
    end

    # Execute the precompile statements
    const precompile_statements = []
    for statement in eachline("$(@__DIR__)/precompile_statements.jl")
        # Main should be completely clean
        occursin("Main.", statement) && continue
        try
            ps = Meta.parse(statement)
            if !Meta.isexpr(ps, :call)
                # these are typically comments
                @debug "skipping statement because it does not parse as an expression" statement
                continue
            end
            popfirst!(ps.args) # precompile(...)
            ps.head = :tuple
            ps = eval(ps)
            push!(precompile_statements, statement => ps)
        catch ex
            # See #28808
            @warn "Failed to precompile expression" form=statement exception=ex _module=nothing _file=nothing _line=0
        end
    end
end

for (statement, ps) in PrecompileStagingArea.precompile_statements
    if precompile(ps...)
        # success
    else
        @warn "Failed to precompile expression" form=statement _module=nothing _file=nothing _line=0
    end
end