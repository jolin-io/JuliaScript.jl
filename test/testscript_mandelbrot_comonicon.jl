using Plots
using Comonicon

function mandelbrot_kernel(c, MAX_ITERS)
    z = c
    for i = 1:MAX_ITERS
        z = z * z + c
        if abs2(z) > 4
            return i
        end
    end
    return MAX_ITERS
end

"""
Build Mandelbrot

# Options

- `--xn <arg>`: x axis resolution
- `--yn <arg>`: y axis resolution
- `--xmin <arg>`: x axis minimum
- `--xmax <arg>`: x axis maximum
- `--ymin <arg>`: y axis minimum
- `--ymax <arg>`: y axis maximum
- `--MAX_ITERS <arg>`: mandelbrot algorithm maximum iterations
"""
@main function compute_mandelbrot(;
    xn = 2000, yn = 2000, xmin = -2.0, xmax = 0.6, ymin = -1.5, ymax = 1.5, MAX_ITERS = 200
)
    result = zeros(yn, xn)

    x_range = range(xmin, xmax, xn)
    y_range = range(ymin, ymax, xn)

    Threads.@threads for j = 1:yn
        for i = 1:xn
            x = x_range[i]
            y = y_range[j]
            result[j, i] = mandelbrot_kernel(complex(x, y), MAX_ITERS)
        end
    end
    
    x_range = range(xmin, xmax, xn)
    y_range = range(ymin, ymax, yn)
    heatmap(x_range, y_range, result)
    savefig("mandelbrot_output.png")
end

