#=

This session builds upon Session 2 where we added locations to the 
Hegselmann-Krause model. The goal is to extend the model by adding 
spatial information to the locations using a 2-dimensional raster.

1. Adding spatial structure
---------------------------
a. Modify the Location struct to include a field `pos`:
   pos::Tuple{Int64, Int64}

b. Create a new move!(sim, id, pos) function that:
   - Creates `CurrentLocation` edges between person `id` and location
     at `pos`
   - Adds `Reachable` edges to surrounding cells with a manhattan
     distance of 1 (Hint: Check the move_to! keywords)

c. Adapt the simulation setup:
   - Rewrite `new_simulation`, add the locations via `add_raster!`
   - Add a transition function after `finish_init!` that calls `move!` 
     with random positions for each agent (use `random_pos`)
   - Update `check_location` to use the `move!` function
   - Adjust `step!` function to include correct `read`/`write` types for
     check_location (reading location states, writing Reachable edges)

d. Benchmark this solution

2. Performance optimization 
---------------------------

Create a copy of the working solution and optimize the performance by:
- Adding hints (check
  https://s-fuerst.github.io/Vahana.jl/stable/performance.html for the
  available hints)
- Disabling Vahana assertions (enable_asserts(false))
- Rewriting update_opinion and check_location to use neighborstates_iter 
  instead of neighborstates

Compare the performance with the previous version.

3. Optional task: Moving computation to locations
-------------------------------------------------

In our current implementation, persons are responsible for calculating
their new opinions and deciding about location changes. As an
interesting alternative, we can shift this responsibility to the
locations themselves. Each location would then compute the new
opinions for all persons present and determine if they should move to
a new location. This reorganization eliminates the need to create
Knows edges between all persons at a location in each time step, which
should improve performance.

To implement this:

a. Replace the Knows edges with a new Update edge type that contains:
   - opinion::Float64 (the calculated new opinion)
   - redraw::Bool (if the person should move to a new location)

b. Add a transition function where locations:
   - Calculate new opinions for all persons at their location
   - Determine if persons should redraw their location
   - Create Update edges to communicate these decisions

c. Add a transition function where persons react to incoming Update edges:
   - Update their opinion based on the Update edge
   - Potentially move to a new location if redraw is true

d. Ajdust the step! method to the new transition functions

Compare the performance with the previous version.

Hint
----

For visualization, you can use the predefined function
plot_raster_graph(sim).  While it supports up to 8000 persons on a
40x40 grid (the default values of run_simulation(), it's recommended
to start with smaller values like 500 persons on a 10x10 grid for
faster visualization

=#

using Vahana
import Statistics: mean
import StatsBase: sample

# plot_raster_graph is defined here, incl. the using statements needed
# for the visualization
include("../support/visualization.jl")

detect_stateless(true)

struct Person
    opinion::Float64
end

struct Knows end

# add the pos field
struct Location end

struct CurrentLocation end

struct Reachable end

struct LogRedraw end

# plot_opinions is defined here, incl. the
# using statements needed for the visualization
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


# raster_size are now a (x-size, y-size) tuple
function new_simulation(num_persons, raster_size, ϵ)
    sim = create_simulation(model)
    # we do not need the personids this time
    add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])
    # create the Locations as raster via `add_raster!`

    set_param!(sim, :ϵ, ϵ)
    
    finish_init!(sim)

    # add a transition function here (before meet) that move the
    # persons to a random position

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

    # replace this with a move! call
    add_edge!(sim, id, lid, CurrentLocation())
    add_edge!(sim, lid, id, CurrentLocation())
end

function step!(sim)
    # update the read and write argument
    apply!(sim, check_location,
           Person,
           [ Person, Knows, Reachable, CurrentLocation ],
           [ LogRedraw, CurrentLocation ])

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

# run the simulation once to compile all methods
sim = run_simulation()

@time sim = run_simulation()
