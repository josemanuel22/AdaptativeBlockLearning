"""
    get_window_of_Aₖ(model, target , K, n_samples)

    Generate a window of the rv's Aₖ for a given model and target function.
"""
function get_window_of_Aₖ(model, target , K, n_samples)
    count.([model.(rand(Normal(μ, stddev), K)') .< target(rand(Normal(μ, stddev))) for _ in 1:n_samples])
end;

"""
    convergence_to_uniform(aₖ)

    Test the convergence of the distributino of the window of the rv's Aₖ to a uniform distribution.
    It is implemented using a Chi-Square test.
"""
function convergence_to_uniform(aₖ)
    return pvalue(ChisqTest(aₖ, fill(1/(K+1), K+1)))
end;
