#=

This is the solution to the first workshop session.

The tasks are described in the assignment file. All comments in this file
refer to the implemented changes and quote the corresponding tasks from
the assignment file. The original comments have been removed.

=#

using Vahana
import Statistics: mean

# The example function is used in the optional task 3
import StatsBase: sample

# using GLMakie

detect_stateless(true)

struct Person
    opinion::Float64
end

# Step 1. Extend the model to include the new Agent and Edge types,
#         and register the new parameter `p`.
struct Knows end

struct Location end

struct CurrentLocation end

struct Reachable end

# This edgetype is used in the optional task 2
struct LogRedraw end

model = ModelTypes() |>
    register_agenttype!(Person) |>
    register_agenttype!(Location) |>
    register_edgetype!(Knows) |>
    register_edgetype!(CurrentLocation) |>
    register_edgetype!(Reachable) |>
    register_edgetype!(LogRedraw) |>
    register_param!(:ϵ, 0.2) |>
    register_param!(:p, 0.1) |> 
    create_model("Hegselmann-Krause")

# Step 2. Adjust the new_simulation function:
#         - Add a new parameter for the number of locations.
# And Optional Task 3: Add a parameter for the number of reachable locations
function new_simulation(num_persons, num_locations, num_reachable, ϵ, p)
    sim = create_simulation(model)
    personids = add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])
    # Step 2. - Add locations by using the `add_agents!` function.
    locationids = add_agents!(sim, [ Location() for _ in 1:num_locations])

    for pid in personids
        # Optional Task 3: Instead of connecting persons to all locations,
        # connect them only to a subset. 
        # Without optional task 3 you could directly use the locationsids
        # vector in the following statements instead of lids.
        lids = sample(locationids, num_reachable; replace = false)
        for lid in lids 
            # Step 2. - Instead of adding edges of type "Knows," create edges 
            #      of type "Reachable" from each location to each person.
            add_edge!(sim, lid, pid, Reachable())
        end
        # Step 2. - For each person, randomly select one location and add edges
        #           of type "CurrentLocation" in both directions.
        start_lid = rand(lids)
        add_edge!(sim, pid, start_lid, CurrentLocation())
        add_edge!(sim, start_lid, pid, CurrentLocation())
    end

    set_param!(sim, :ϵ, ϵ)
    set_param!(sim, :p, p)
    
    finish_init!(sim)

    # Step 3. - Call this transition function ...
    apply!(sim, meet, Location, CurrentLocation, Knows)
    
    sim
end

# Step 3. Write a new transition function where each location connects
# all persons at that location with edges of type "Knows".
function meet(_, id, sim)
    # first check that there is any person on this location
    if num_edges(sim, id, CurrentLocation) > 0
        # then iterate over the personids at this location
        # and create the edges between them
        nids = neighborids(sim, id, CurrentLocation)
        for nid1 in nids
            for nid2 in nids
                add_edge!(sim, nid1, nid2, Knows())
            end 
        end
    end
end 

# There is no need to change anything here, isn't that nice ;-)        
function update_opinion(state, id, sim)
    ϵ = param(sim, :ϵ)

    opinions = map(a -> a.opinion, neighborstates(sim, id, Knows, Person))

    accepted = filter(opinions) do opinion
        abs(opinion - state.opinion) < ϵ
    end
    
    Person(mean(accepted))
end

# Step 4. Write a new transition function where each person updates their
# current location, following the rule described above. Hint: In the
# simplest implementation, all "CurrentLocation" edges will be
# re-added, even when the person did not moved to a new location.
function update_location_randomly(_, id, sim)
    # in Julia the if statement returns a value, so each branch determines
    # the new location id, which is then after the the if statement to
    # add the edges to this location id
    lid = if rand() < param(sim, :p)
        # Optional taks 2: add a new edge type called `LogRedraw` that creates
        # an edge from/to a person whenever that person reassigns the location.
        add_edge!(sim, id, id, LogRedraw())
        rand(neighborids(sim, id, Reachable))
    else
        # Without `Hints` (which will be discussed later)
        # neighborids returns always a vector, even if it
        # has only one element. So we use the `first`
        # method to convert it to a single location id.
        first(neighborids(sim, id, CurrentLocation))
    end

    add_edge!(sim, id, lid, CurrentLocation())
    add_edge!(sim, lid, id, CurrentLocation())
end

# Option Task 1: Modify the rule from step 4: Instead of reselecting
# the location at random times, only reselect it when the majority of
# opinions (including the agent's own opinion) lies outside the
# agent's confidence bound. Create an additional transition function
# for this behavior.
function update_location_confidence(state, id, sim)
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


function step!(sim)
    # must be after `update_opinion` or before `meet` as in the
    # other cases the Knows edges does not match the current locations.
    apply!(sim, update_location_randomly,
           Person,
           [ Reachable, CurrentLocation ],
           [ LogRedraw, CurrentLocation ])

    # or for applying the transition function of Optional Task 1: 
    # apply!(sim, update_location_confidence,
    #        Person,
    #        [ Person, Knows, Reachable, CurrentLocation ],
    #        [ LogRedraw, CurrentLocation ])

    # 5. Apply this transition function in the `step!` function.
    # `meet` must be applied before `update_opinion`, as it
    # will create the `Knows` edges.
    apply!(sim, meet, Location, CurrentLocation, Knows)

    apply!(sim, update_opinion, Person, [ Person, Knows ], Person)
end

# 6. Add the new parameters also to `run_simulation`
function run_simulation(;
                        num_persons = 20,
                        num_locations = 5,
                        num_reachable = 3,
                        ϵ = 0.2,
                        p = 0.1,
                        num_steps = 100)
    sim = new_simulation(num_persons, num_locations, num_reachable, ϵ, p)
    for _ in 1:num_steps
        step!(sim)
    end

    sim
end

sim = run_simulation(; num_persons = 30, num_locations = 6)

