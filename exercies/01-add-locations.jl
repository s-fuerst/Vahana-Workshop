#=

This is the existing implementation of the Hegselmann-Krause Opinion
model, taken from here:
https://s-fuerst.github.io/Vahana.jl/stable/hegselmann.html

The goal of this exercise is to extend the Hegselmann-Krause model by
adding different locations where individuals interact with each other.

In this workshop session, the locations do not have any spatial
relationship; we will add this feature later. Instead, locations
should be added to the graph as a new type of vertex (e.g., called
'Location'). Edge between a person and a location are created when the
person visits that location. These edges will have a new type, which
we can call 'CurrentLocation'.

When an agent updates its opinion, it will only consider the opinions
of other individuals at the same location. This can be achieved by
constructing the edges of type 'Known' in a transition function,
connecting all agents at the same location.

As the term 'Current' implies, individuals can switch between
locations after updating their opinions. Therefore, we will add a new
rule:

- Persons randomly select a new location with a probability determined
  by a new parameter 'p'. If the number drawn via the 'rand()' method
  is smaller than 'p', they randomly choose a location from the list
  of reachable locations (use `rand(reachable)` for this).  It is
  allowed that the persons will stay at the same location when this is
  drawn again.

This raises the question of how "reachable" is defined. In the
simplest case, every location could be considered
"reachable". However, it requires little additional effort to restrict
this to a selection of locations. The latter is an optional task. In
any case, edges from the "reachable" locations to the individuals are
needed, and to distinguish these from 'CurrentEdge', they require a
new edge type, e.g., with the name 'Reachable'.

So, the overall task consists of the following steps:

1. Extend the model to include the new Agent and Edge types, 
   and register the new parameter `p`.

2. Adjust the new_simulation function:

   - Add a new parameter for the number of locations.
   - Add locations by using the `add_agents!` function.
   - Instead of adding edges of type "Knows," create edges of type
     "Reachable" from each location to each person.
   - For each person, randomly select one location and add edges
     of type "CurrentLocation" in both directions.

3. Write a new transition function where each location connects all
   persons at that location with edges of type `Knows`. Call this
   transition function in `new_simulation` after `finish_init!` so
   that in the initial state of the simulation we have a "correct"
   graph.

4. Write a new transition function where each person updates their
   current location, following the rule described above. Hint: In the
   simplest implementation, all "CurrentLocation" edges will be
   re-added, even when the person did not moved to a new location.

5. Apply this transition function in the `step!` function.

6. Add the new parameters also to `run_simulation`

Optional tasks (if time permits):

1. Modify the rule from step 4: Instead of reselecting the location at
   random times, only reselect it when the majority of opinions
   (including the agent's own opinion) lies outside the agent's
   confidence bound. Create an additional transition function for this
   behavior.

2. To track location changes over time, add a new edge type called
   `LogRedraw` that creates an edge from/to a person whenever that
   person reassigns their location. While this doesn't affect the
   simulation dynamics, it can be useful for analyzing movement
   patterns.

3. Instead of connecting persons to all locations, connect them only
   to a subset. Add a parameter for the number of reachable locations
   in the `new_simulation` method. You can use the `sample` function
   from the `StatsBase` package to select the locations (Hint: set
   `replace=false` in `sample`).

Tip:

- You can only reevaluate a `ModelTypes() |> .... |> create_model(name)`
  chain with different agent/edgetypes in the same Julia REPL session
  when you change the `name` argument of `create_model`

=#

using Vahana
import Statistics: mean

# suppress the ":Stateless hint" warning, we will come back to this later
detect_stateless(true)

struct Person
    opinion::Float64
end

# An individual can only be influenced by another person if there
# exists a direct "Knows" relationship connection between them.
struct Knows end

model = ModelTypes() |>
    register_agenttype!(Person) |>
    register_edgetype!(Knows) |>
    # Beside these two types there is a *confidence bound* $\epsilon > 0$,
    # opinions with a difference greater than $\epsilon$ are ignored by
    # the agents in the transition function. All agents have the same
    # confidence bound, so we introduce this bound as a parameter.
    register_param!(:ϵ, 0.2) |> 
    create_model("Hegselmann-Krause")

function new_simulation(num_persons, ϵ)
    sim = create_simulation(model)
    personids = add_agents!(sim, [ Person(rand()) for _ in 1:num_persons])

    # This time we create the complete graph outself, as we want to modify
    # the structure in the following exercices
    for pid in personids 
        for pid2 in personids
            add_edge!(sim, pid, pid2, Knows())
        end
    end

    set_param!(sim, :ϵ, ϵ)
    
    finish_init!(sim)

    sim
end

function update_opinion(state, id, sim)
    ϵ = param(sim, :ϵ)

    opinions = map(a -> a.opinion, neighborstates(sim, id, Knows, Person))

    accepted = filter(opinions) do opinion
        abs(opinion - state.opinion) < ϵ
    end
    
    Person(mean(accepted))
end

function step!(sim)
    apply!(sim, update_opinion, Person, [ Person, Knows ], Person)
end

function run_simulation(;num_persons = 20, ϵ = 0.2, num_steps = 100)
    sim = new_simulation(num_persons, ϵ)

    for _ in 1:num_steps
        step!(sim)
    end

    sim
end

sim = run_simulation(;num_persons = 30)

