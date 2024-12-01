
#=

This is the solution for the second part of (benchmarking)
of the third workshop session.

This solution builds upon the solution of the first part of the third
session. The previous comments have been removed, and new comments
focus on explaining changes made to fulfill the current assignment's
requirements.

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

struct Location
    pos::Tuple{Int64, Int64}
end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

# plot_opinions is defined here, incl. the
# using statements needed for the visualization
include("../support/visualization.jl")

# 2.: Adding Hints
model = ModelTypes() |>
    register_agenttype!(Person, :Immortal) |>
    register_agenttype!(Location, :Immortal, :Independent) |>
    register_edgetype!(Knows, :SingleType; target = Person) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable, :SingleType; target = Person) |>
    register_edgetype!(LogRedraw, :HasEdgeOnly, :SingleType; target = Person) |>
    register_param!(:ϵ, 0.2) |>
    create_model("Hegselmann-Krause-With-Hints")


function move!(sim, id, pos)
    move_to!(sim, :locations, id, pos,
             CurrentLocation(), CurrentLocation())
    move_to!(sim, :locations, id, pos,
             Reachable(), nothing;
             distance = 1, only_surrounding = true, metric = :manhatten)
end

function new_simulation(num_persons, raster_size, ϵ)
    sim = create_simulation(model)
    add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])
    add_raster!(sim, :locations, raster_size, pos -> Location(pos))
    
    finish_init!(sim)

    apply!(sim, Person, [], [ CurrentLocation, Reachable ]) do _, id, sim
        move!(sim, id, random_pos(sim, :locations))
    end

    apply!(sim, meet, Location, CurrentLocation, Knows)
    
    sim
end

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

function update_opinion(state, id, sim)
    ϵ = param(sim, :ϵ)

    # 2.: use neighborstates_iter
    opinions_sum = 0.0
    opinions_num = 0
    for stateother in neighborstates_iter(sim, id, Knows, Person)
        other_opinion = stateother.opinion
        if abs(state.opinion - other_opinion) < ϵ
            opinions_num += 1
            opinions_sum += other_opinion
        end
    end
    
    Person(opinions_sum / opinions_num)
end

function check_location(state, id, sim)
    ϵ = param(sim, :ϵ)

    # 2.: use neighborstates_iter
    num_inside_confidence = 0
    for stateother in neighborstates_iter(sim, id, Knows, Person)
        if abs(state.opinion - stateother.opinion) < ϵ
            num_inside_confidence += 1
        end
    end
    
    lid = if num_inside_confidence / num_edges(sim, id, Knows) < 0.5
        add_edge!(sim, id, id, LogRedraw())
        rand(neighborids(sim, id, Reachable))
    else
        neighborids(sim, id, CurrentLocation) |> first
    end

    move!(sim, id, agentstate(sim, lid, Location).pos)
end

function step!(sim)
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

    for s in 1:num_steps
        step!(sim)
    end

    sim
end

# 2.: Disabling Vahana assertions
enable_asserts(false)

# run the simulation once to compile all methods
sim = run_simulation()

@time sim = run_simulation()
