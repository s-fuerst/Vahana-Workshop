#=

This is the solution to the second workshop session.

This solution builds upon Session 1's solution. The previous comments
have been removed, and new comments focus on explaining changes made
to fulfill the current assignment's requirements.

=#

using Vahana
import Statistics: mean
import StatsBase: sample

detect_stateless(true)

struct Person
    opinion::Float64
end

struct Knows end

struct Location end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

# plot_opinions is defined here, incl. the using statements needed for visualization
include("../support/visualization.jl")

model = ModelTypes() |>
    register_agenttype!(Person) |>
    register_agenttype!(Location) |>
    register_edgetype!(Knows) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable) |>
    register_edgetype!(LogRedraw) |>
    register_param!(:ϵ, 0.2) |>
    # 2a.: register a global value ...
    register_global!(:mean_opinion, Float64[]) |>
    create_model("Hegselmann-Krause-Analysis")

# no need to change anything
function new_simulation(num_persons, num_locations, num_reachable, ϵ)
    sim = create_simulation(model)
    personids = add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])
    locationids = add_agents!(sim, [ Location() for _ in 1:num_locations])

    for pid in personids
        lids = sample(locationids, num_reachable; replace = false)
        for lid in lids 
            add_edge!(sim, lid, pid, Reachable())
        end
        start_lid = rand(lids)
        add_edge!(sim, pid, start_lid, CurrentLocation())
        add_edge!(sim, start_lid, pid, CurrentLocation())
    end

    set_param!(sim, :ϵ, ϵ)
    
    finish_init!(sim)

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

# no need to change anything
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
    
    add_edge!(sim, id, lid, CurrentLocation())
    add_edge!(sim, lid, id, CurrentLocation())
end

# no need to change anything
function step!(sim)
    apply!(sim, check_location,
           Person,
           [ Person, Knows, Reachable, CurrentLocation ],
           [ LogRedraw, CurrentLocation ])

    apply!(sim, meet, Location, CurrentLocation, Knows)

    apply!(sim, update_opinion, Person, [ Person, Knows ], Person)
end

function run_simulation(;
                 num_persons = 20,
                 num_locations = 5,
                 num_reachable = 3,
                 ϵ = 0.2,
                 num_steps = 40)
    sim = new_simulation(num_persons, num_locations, num_reachable, ϵ)

    # 1a.: In `run_simulation` write a snapshot after `new_simulation`
    write_snapshot(sim, "0") 
    # 1b.: Write the number of steps of the simulation as metadata
    write_sim_metadata(sim, :num_steps, num_steps)

    for s in 1:num_steps
        step!(sim)
        # 2b.: after the step! function caluclate the fraction ...
        push_global!(sim, :mean_opinion,
                     mapreduce(sim, p -> p.opinion, +, Person) /
                        num_agents(sim, Person))
        # 1a.: ... and after each `step!` ...
        write_snapshot(sim, string(s))
    end

    sim
end

# 1c.: Introduce a new function `read_opinions!(sim)` ...
function read_opinions!(sim)
    opinions = Vector{Vector{Float64}}()

    num_steps = read_sim_metadata(sim, :num_steps)

    for s in 0:num_steps
        read_snapshot!(sim; comment = string(s))
        push!(opinions, map(p -> p.opinion, all_agents(sim, Person)))
    end

    opinions
end

# Visualization of simulation runs
colors = Colors.range(Colors.colorant"red",
                      stop = Colors.colorant"green",
                      length = 100);

function modify_viz(state::Person, _, _)
    Dict(:node_color => colors[Int(ceil(state.opinion * 100))],
         :node_size => 20)
end

# 3a. (incl. 3d.): Add a new modify_viz method for the locations
function modify_viz(state::Location, id, vp)
    opinions = map(p -> p.opinion,
                   neighborstates(vp.sim, id, CurrentLocation, Person))
    identical_opinions = all(x -> x == first(opinions), opinions)
    num_persons = num_edges(vp.sim, id, CurrentLocation)
    Dict(:node_marker => :rect,
         :node_color => identical_opinions ? :purple : :blue,
         :node_size => 5 + 4 * num_persons)
end

# 3b.: Add a modify_viz method for the edges...
function modify_viz(_, from, to, vp)
    if from == clicked_agent(vp) || to == clicked_agent(vp)
        Dict(:edge_width => 1,
             :arrow_size => 10)
    else
        Dict(:edge_width => 0.2,
             :arrow_size => 0)
    end
end

function plot_graph(sim)
    vp = create_graphplot(sim, update_fn = modify_viz)
    Makie.hidedecorations!(axis(vp))
    Makie.Colorbar(figure(vp)[:, 2]; colormap = colors)
    resize!(figure(vp), 900, 800)
    figure(vp)
end

sim = run_simulation(; num_persons = 30, num_locations = 6)

# 1d.:
read_opinions!(sim) |> plot_opinions

# 2c.:
plot_globals(sim, [:mean_opinion]) |> first

# 3c.:
plot_graph(sim)
