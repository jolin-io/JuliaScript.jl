# JuliaScript

[![Build Status](https://github.com/jolin-io/JuliaScript.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolin-io/JuliaScript.jl/actions/workflows/CI.yml?query=branch%3Amain)

## You have a julia script.jl and want to run it fast?

Welcome to `juliascript` which was build for exactly that purpose.

1. Make sure [`julia` is installed via juliaup](https://github.com/JuliaLang/juliaup)
2. Then run the following in a linux bash terminal
  ```bash
  curl -o ~/.juliaup/bin/juliascript -fsSL 
  chmod +x ~/.juliaup/bin/juliascript
  ```

Now you can run `juliascript yourscript.jl` on the terminal, or use the shebang `#!/usr/bin/env juliascript` as the first line of your exectuable script.

## How it works

- The first time `juliascript` runs `yourscript.jl` it will create a corresponding julia module and track all precompile statements from the actual run.
- From the second time onwards it will then run as fast as julia's precompilation system allows for it


## Further speedup
Sometimes the speedup this gives may not be satisfying. Then you can manually create a **sysimage** to improve performance even further. Just do
```bash
juliascript packagecompile yourscript.jl
```
Depending on your script this may take from 5 minutes up to 30 minutes.

EXPERIMENTAL: You can set the environment variable `export JULIASCRIPT_PACKAGECOMPILE_ALWAYS=true` so that packagecompile will be called automatically in the background as soon as `juliascript` is run on a new script.jl.




