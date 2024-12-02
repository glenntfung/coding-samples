using OptimalTransport, Statistics, Distributions, Distances, StatsBase, StatsPlots, Dates, DataFrames, CSV, JSON

# Define a function to read JSONL file
function read_jsonl(file_path)
    entries = []
    open(file_path, "r") do io
        for line in eachline(io)
            push!(entries, JSON.parse(line))
        end
    end
    return entries
end

# Parse the JSONL file
file_path = "path.jsonl"  # Replace with the path to your JSONL file
data = read_jsonl(file_path)

# Extract required columns: ratings and timestamps
ratings = Float64[]
timestamps = Int[]
for entry in data
    push!(ratings, entry["rating"])
    push!(timestamps, entry["timestamp"] ÷ 1000)  # Convert to seconds from milliseconds
end

# Create a DataFrame
df = DataFrame(rating = ratings, timestamp = timestamps)

# Convert timestamps to Date
df.timestamp = Dates.unix2datetime.(df.timestamp)

# Split the data into two parts
df_2020_2023 = filter(row -> row.timestamp >= DateTime(2020, 1, 1) && row.timestamp < DateTime(2024, 1, 1), df)
df_2016_2019 = filter(row -> row.timestamp >= DateTime(2016, 1, 1) && row.timestamp < DateTime(2020, 1, 1), df)

# Plot distributions of ratings
p1 = @df df_2020_2023 histogram(:rating, bins=1:6, closed=:left, label="2020-2023", title="Ratings Distribution (2020-2023)", xlabel="Rating", ylabel="Frequency", legend=:topright)
p2 = @df df_2016_2019 histogram(:rating, bins=1:6, closed=:left, label="2016-2019", title="Ratings Distribution (2016-2019)", xlabel="Rating", ylabel="Frequency", legend=:topright)

# Display plots
plot(p1, p2, layout=(2, 1))

# Define the function to compute the Wasserstein distance and bootstrap confidence intervals
function compare_distributions(vec1::Vector{Float64}, vec2::Vector{Float64}; num_bootstrap=1000, alpha=0.05)
    # Ensure unique support for the empirical distributions
    counts_vec1 = countmap(vec1)
    counts_vec2 = countmap(vec2)
    
    unique_vec1 = collect(keys(counts_vec1))
    weights1 = collect(values(counts_vec1)) ./ length(vec1)
    
    unique_vec2 = collect(keys(counts_vec2))
    weights2 = collect(values(counts_vec2)) ./ length(vec2)

    # Create DiscreteNonParametric distributions
    dist1 = DiscreteNonParametric(unique_vec1, weights1)
    dist2 = DiscreteNonParametric(unique_vec2, weights2)

    # Wasserstein distance between the empirical distributions
    wasserstein_dist = OptimalTransport.wasserstein(dist1, dist2; metric=SqEuclidean(), p=Val(2))

    # Bootstrap for confidence intervals
    bootstrap_dists = zeros(num_bootstrap)
    for i in 1:num_bootstrap
        resample_vec1 = vec1[rand(1:length(vec1), length(vec1))]  # Resample vec1 with replacement
        resample_vec2 = vec2[rand(1:length(vec2), length(vec2))]  # Resample vec2 with replacement

        # Ensure unique support for resampled distributions
        resample_counts_vec1 = countmap(resample_vec1)
        resample_unique_vec1 = collect(keys(resample_counts_vec1))
        resample_weights1 = collect(values(resample_counts_vec1)) ./ length(resample_vec1)

        resample_counts_vec2 = countmap(resample_vec2)
        resample_unique_vec2 = collect(keys(resample_counts_vec2))
        resample_weights2 = collect(values(resample_counts_vec2)) ./ length(resample_vec2)

        # Create resampled DiscreteNonParametric distributions
        resample_dist1 = DiscreteNonParametric(resample_unique_vec1, resample_weights1)
        resample_dist2 = DiscreteNonParametric(resample_unique_vec2, resample_weights2)

        # Recompute Wasserstein distance for resampled distributions
        bootstrap_dists[i] = OptimalTransport.wasserstein(resample_dist1, resample_dist2; metric=SqEuclidean(), p=Val(2))
    end

    # Compute confidence interval
    lower = quantile(bootstrap_dists, alpha / 2)
    upper = quantile(bootstrap_dists, 1 - alpha / 2)

    return wasserstein_dist, (lower, upper)
end

# Extract ratings as Vector{Float64} from the two DataFrames
vec1 = df_2020_2023.rating |> Vector{Float64}
vec2 = df_2016_2019.rating |> Vector{Float64}

# Computing
wasserstein_distance, confidence_interval = compare_distributions(vec1, vec2)

println("Wasserstein Distance: ", wasserstein_distance)
println("Confidence Interval: ", confidence_interval)