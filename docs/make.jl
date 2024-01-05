using JuliaScript
using Documenter

DocMeta.setdocmeta!(JuliaScript, :DocTestSetup, :(using JuliaScript); recursive=true)

makedocs(;
    modules=[JuliaScript],
    authors="Stephan Sahm <stephan.sahm@jolin.io> and contributors",
    repo="https://github.com/jolin-io/JuliaScript.jl/blob/{commit}{path}#{line}",
    sitename="JuliaScript.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jolin-io.github.io/JuliaScript.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jolin-io/JuliaScript.jl",
    devbranch="main",
)
