
#=

This is the solution of the optional task of session 3.

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

struct Location
    pos::Tuple{Int64, Int64}
end

# 3a.: Replace the Knows edges with a new Update edge type
struct Update
    opinion::Float64
    redraw::Bool
end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

# plot_raster_graph is defined here, incl. the using statements needed
# for the visualization
include("../support/visualization.jl")

model = ModelTypes() |>
    register_agenttype!(Person, :Immortal, :Independent) |>
    register_agenttype!(Location, :Immortal, :Independent) |>
    # we can not combine :SingleEdge and :SingleType
    register_edgetype!(Update, :SingleEdge, :IgnoreFrom) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable, :SingleType; target = Person) |>
    register_edgetype!(LogRedraw, :HasEdgeOnly, :SingleType; target = Person) |>
    register_param!(:ϵ, 0.2) |>
    create_model("Hegselmann-Krause-Locations-calc")

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

    sim
end

# 3b.
function calc_opinion(state, id, sim)
    ϵ = param(sim, :ϵ)

    num_persons = num_edges(sim, id, CurrentLocation)

    if num_persons > 0
        pids = neighborids(sim, id, CurrentLocation)
        opinions = map(p -> p.opinion,
                       neighborstates_iter(sim, id, CurrentLocation, Person)) 

        for (i, pid) in enumerate(neighborids_iter(sim, id, CurrentLocation))
            opinions_sum = 0.0
            opinions_num = 0
            for other in opinions
                if abs(opinions[i] - other) < ϵ
                    opinions_num += 1
                    opinions_sum += other
                end
            end

            add_edge!(sim, id, pid, Update(opinions_sum / opinions_num,
                                           (opinions_num / num_persons) < 0.5))
        end
    end
end

# 3c.: Add a transition function where persons react to incoming Update edges
function update_opinion(state, id, sim)
    # we do not need first this time, as Update has the hint :SingleEdge
    update = edgestates(sim, id, Update)

    lid = if update.redraw
        add_edge!(sim, id, id, LogRedraw())
        rand(neighborids(sim, id, Reachable))
    else
        neighborids(sim, id, CurrentLocation) |> first
    end

    move!(sim, id, agentstate(sim, lid, Location).pos)
    
    Person(update.opinion)
end

# 3d.: Ajdust the step! method to the new transition functions
function step!(sim)
    apply!(sim, calc_opinion,
           Location,
           [ Person, CurrentLocation ],
           Update)

    apply!(sim, update_opinion,
           Person,
           [ Update, Reachable, Location, CurrentLocation ],
           [ Person, LogRedraw, Reachable, CurrentLocation ])
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

# run the simulation once to compile all methods
enable_asserts(false)

sim = run_simulation()

@time sim = run_simulation()
