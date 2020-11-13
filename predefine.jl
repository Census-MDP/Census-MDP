using Distributions, Random, CSV, DataFrames

# num_tracts^length(percentage_buckets) possible states
num_tracts = 10
percentage_buckets = collect(0:0.2:1)

Random.seed!(238)

# education = ["high_school", "college_grad"]
econ = ["low_income", "avg_income", "high_income"]
# race = ["white", "black", "native", "alaska_native", "asian", "hawaiian", "pacific_islander"] # official census buckets
demo_types = econ

struct ResponseInc
  self_resp_inc::Distribution
  followup_inc::Distribution
end

response_inc_demo_file = "response_inc_demo.csv"
response_inc_demo = Dict()
for row in CSV.File(read(joinpath(@__DIR__, response_inc_demo_file)))
  response_inc_demo[row.demo] = ResponseInc(
    Normal(row.self_resp_inc_mean, row.self_resp_inc_std),
    Normal(row.followup_inc_mean, row.followup_inc_std),
  )
end

function genStates(num_states, demo, file)
  df = DataFrame()
  for d in demo
    df[d] = zeros(num_states)
  end
  for row in eachrow(df)
    r = rand(1, length(demo))
    r = r / sum(r)
    row[:] = r
  end
  CSV.write(joinpath(@__DIR__, file), df)
end

tract_file = "tract_demo.csv"
genStates(num_tracts, demo, tract_file)

tract_demo = CSV.File(joinpath(@__DIR__, tract_file)) |> DataFrame

struct Tract
  id::Int
  response_rate::Float64
  response_rate_bucket::Float64
end

function T(s, a)
  sp = copy(s)
  map(update_tracts!(a), sp)
  return sp
end

# findnearest gets the index of the item that is closest to the given value.
findnearest(A::AbstractArray,t) = findmin(abs.(A.-t))[2]

function update_tracts!(a)
  return function(tract::Tract)
    demo = tract_demo[tract.id]
    total_increase = 0
    if tract.id == a
      map_func = get_increase(demo, "self_resp_inc")
      avg(map(map_func, demo_types))
    else
      map_func = get_increase(demo, "followup_inc")
      avg(map(map_func, demo_types))
    end
    sp.response_rate += total_increase
    sp.response_rate_bucket = findnearest(percentage_buckets, response_rate)# round response rate to bucket
  end
end

function get_increase(demo::DataFrameRow, inc_type)
  return function(demo_type::String)
    sym = Symbol(inc_type)
    return rand(getfield(response_inc_demo[demo_type], sym)) * demo[demo_type]
  end
end
