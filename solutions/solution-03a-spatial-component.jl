
#=

This is the solution for the first part of (adding a spatial component)
of the third workshop session.

This solution builds upon Session 2's solution. The previous comments
have been removed, and new comments focus on explaining changes made
to fulfill the current assignment's requirements.

=#

using Vahana
import Statistics: mean
import StatsBase: sample

using BenchmarkTools
using OhMyREPL


detect_stateless(true)

struct Person
    opinion::Float64
end

struct Knows end

# 1a.: Modify the Location struct 
struct Location
    pos::Tuple{Int64, Int64}
end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

# plot_raster_graph is defined here, incl. the using statements needed
# for the visualization
include("../support/visualization.jl")

model = ModelTypes() |>
    register_agenttype!(Person) |>
    register_agenttype!(Location) |>
    register_edgetype!(Knows) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable) |>
    register_edgetype!(LogRedraw) |>
    register_param!(:ϵ, 0.2) |>
    create_model("Hegselmann-Krause-Raster")

# 1b.: Create a new move!(sim, id, pos) function
function move!(sim, id, pos)
    move_to!(sim, :locations, id, pos,
             CurrentLocation(), CurrentLocation())
    move_to!(sim, :locations, id, pos,
             Reachable(), nothing;
             distance = 1, only_surrounding = true, metric = :manhatten)
end


# num_locations are now a (x-size, y-size) tuple
function new_simulation(num_persons, raster_size, ϵ)
    sim = create_simulation(model)
    add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])
    # 1c.: add the locations via `add_raster!`
    add_raster!(sim, :locations, raster_size, pos -> Location(pos))
    
    finish_init!(sim)

    # 1c.: Add a transition function after `finish_init!` that calls `move!` 
    apply!(sim, Person, [], [ CurrentLocation, Reachable ]) do _, id, sim
        move!(sim, id, random_pos(sim, :locations))
    end

    apply!(sim, meet, Location, CurrentLocation, Knows)
    
    sim
end

# no need to change anything
function meet(_, id, sim)
    if num_edges(sim, id, CurrentLocation) > 0
        nids = neighborids(sim, id, CurrentLocation)
        for nid1 in nids
            for nid2 in nids
                add_edge!(sim, nid1, nid2, Knows())
            end 
        end
    end
end 

# no need to change anything
function update_opinion(state, id, sim)
    ϵ = param(sim, :ϵ)

    opinions = map(a -> a.opinion, neighborstates(sim, id, Knows, Person))

    accepted = filter(opinions) do opinion
        abs(opinion - state.opinion) < ϵ
    end
    
    Person(mean(accepted))
end

function check_location(state, id, sim)
    ϵ = param(sim, :ϵ)

    opinions = map(a -> a.opinion, neighborstates(sim, id, Knows, Person))

    num_inside_confidence = count(opinions) do opinion
        abs(opinion - state.opinion) < ϵ
    end
    
    lid = if num_inside_confidence / num_edges(sim, id, Knows) < 0.5
        add_edge!(sim, id, id, LogRedraw())
        rand(neighborids(sim, id, Reachable))
    else
        neighborids(sim, id, CurrentLocation) |> first
    end

    # Update `check_location` to use the `move!` function
    move!(sim, id, agentstate(sim, lid, Location).pos)
end

function step!(sim)
    # 1c: Adjust `step!` function to include correct `read`/`write` types 
    apply!(sim, check_location,
           Person,
           [ Person, Knows, Reachable, CurrentLocation, Location ],
           [ LogRedraw, CurrentLocation, Reachable ])

    apply!(sim, meet, Location, CurrentLocation, Knows)

    apply!(sim, update_opinion, Person, [ Person, Knows ], Person)
end

function run_simulation(;
                        num_persons = 8000,
                        raster_size = (40, 40),
                        ϵ = 0.2,
                        num_steps = 40)

    sim = new_simulation(num_persons, raster_size, ϵ)

    for _ in 1:num_steps
        step!(sim)
    end

    sim
end

# 1d. Benchmark this solution
# run the simulation once to compile all methods
sim = run_simulation()

@time sim = run_simulation()

# or @benchmark sim = run_simulation()
