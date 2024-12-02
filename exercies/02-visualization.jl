#=

This session builds upon Session 1's solution incl. all optional
tasks. As the results are more interessting in the case, that the
persons reselect the location only in the case that the majority of
opinions lies outside the agents confidence bound, this transition
functions is used in the following.

This session has three main topics:
1. Writing and restoring simulations
2. Working with global values
3. Visualization of simulations run


1. Writing and restoring simulations
------------------------------------
(https://s-fuerst.github.io/Vahana.jl/stable/hdf5.html)

a. In `run_simulation` write a snapshot after `new_simulation` with
   via `write_snapshot` with the comment "0" and after each `step!`
   with the current step number (use `string` to convert the value to
   a String).

b. Write the number of steps of the simulation as metadata via
   `write_sim_metadata`.

c. Introduce a new function `read_opinions!(sim)`, that iterate over the
   steps, read the snapshot for those steps, and add the opinions of
   the persons at this step to a `Vector{Vector{Float64}}()`. The
   outer vector are the steps, the inner vector the opinions of this
   step. (Hint: use `push!` to add the opinions to this vector of
   vectors, use `all_agents` to get the state of all persons and `map`
   or list comprehension to extract the opinions from the state
   struct).

d. call the prepared function `plot_opinions` on this vector of vector
   (e.g.: `read_opinions!(sim) |> plot_opinions`).

2. Working with global values
-----------------------------
(https://s-fuerst.github.io/Vahana.jl/stable/global.html)

a. Register a global value that tracks the mean opinion across all
   persons (although this metric may not be particularly meaningful
   in this context).

b. After the step! function calculate this mean via `mapreduce(sim, f, op,
   ::Type{T})` and `num_agents` and push it to this global value.

c. Run a simulation and use the `plot_globals` to plot this fraction.

3. Visualization of simulation run
----------------------------------

At the end of this file you will find a slightly adjusted
`plot_opinion` (and renamed to `plot_graph` function of the HK tutorial:
(https://s-fuerst.github.io/Vahana.jl/stable/hegselmann.html) 

a. Add a new modify_viz method for the Locations, and set the marker
   symbol to a rectangle (the symbol for this is :rect).

b. Add a modify_viz method for the edges, so that only edges that are
   connected with the last clicked person or location are shown with
   arrows (use :arrow_size => 10) and a `edge_with` of 1. Set the
   `:edge_width` to 0.2, and the `: arrow_size` to 0.

c. When you run the `plot_graph` function, you will see some "Edge
   ... will not be shown" warnings, as there is currently the
   restriction that the graph can only show max. two edges between two
   nodes and one loop. As a consequence the LogRedraw edges are not
   visibile. Restrict the `edgetypes` of `create_graphplot` to
   `[ CurrentLocation, LogRedraw ]` to check which persons redraw
   the location in the last step.

Optionally:

d. It would be nice if the location nodes would also show some
   information. So in the modify_viz method for the Locations, check
   if all persons at the locations have the same opinion and/or
   calculate the number of persons on this cell. You can use the
   `neighborstates` and `num_edges` functions for this, you get the
   simulation reference via `vp.sim` where `vp` is the forth argument
   of the modify_viz method. Use a different color to visualize that
   all persons have the same opinion, the adjust the node size in
   depedency of the number of persons.

=#

using Vahana
import Statistics: mean
import StatsBase: sample

# plot_opinions is defined here, incl. the
# using statements needed for the visualization
include("../support/visualization.jl")

detect_stateless(true)

struct Person
    opinion::Float64
end

struct Knows end

struct Location end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

model = ModelTypes() |>
    register_agenttype!(Person) |>
    register_agenttype!(Location) |>
    register_edgetype!(Knows) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable) |>
    register_edgetype!(LogRedraw) |>
    register_param!(:ϵ, 0.2) |>
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

    for s in 1:num_steps
        step!(sim)
    end

    sim
end

# Visualization of simulation runs
colors = Colors.range(Colors.colorant"red",
                      stop = Colors.colorant"green",
                      length = 100)

modify_vis(state::Person, _ ,_) = Dict(:node_color => colors[state.opinion * 100 |> ceil |> Int],
                                       :node_size => 15)

modify_vis(_::Knows, _, _, _) = Dict(:edge_color => :lightgrey,
                                     :edge_width => 0.5);

function plot_graph(sim)
    vp = create_graphplot(sim, update_fn = modify_vis)
    Makie.hidedecorations!(axis(vp))
    Makie.Colorbar(figure(vp)[:, 2]; colormap = colors)
    resize!(figure(vp), 900, 800)
    figure(vp)
end

sim = run_simulation(; num_persons = 30, num_locations = 6)

