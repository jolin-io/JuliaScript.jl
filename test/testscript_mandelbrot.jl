using Plots 

const xn = 960
const yn = 960
const xmin = -2.0
const xmax = 0.6
const ymin = -1.5
const ymax = 1.5
const MAX_ITERS = 200

function mandelbrot_kernel(c)
    z = c
    for i = 1:MAX_ITERS
        z = z * z + c
        if abs2(z) > 4
            return i
        end
    end
    return MAX_ITERS
end


function compute_mandelbrot()
    result = zeros(yn, xn)

    x_range = range(xmin, xmax, xn)
    y_range = range(ymin, ymax, xn)

    Threads.@threads for j = 1:yn
        for i = 1:xn
            x = x_range[i]
            y = y_range[j]
            result[j, i] = mandelbrot_kernel(complex(x, y))
        end
    end
    return result
end

result = compute_mandelbrot()

x_range = range(xmin, xmax, xn)
y_range = range(ymin, ymax, yn)
heatmap(x_range, y_range, result)
savefig("mandelbrot_output.png")