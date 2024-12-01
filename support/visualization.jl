using WGLMakie
using GraphMakie
using Colors

function plot_opinions(ops::Matrix{Float64})
    (num_steps, num_persons) = size(ops)
    
    f = Figure(; size = (1000, 800))
    ax = Axis(f[1,1])
    for i in 1:num_persons
        lines!(ax, 0:(num_steps-1), ops[:,i], alpha = 0.2, color = "red")
    end
    f
end

function plot_opinions(ops::Vector{Vector{Float64}})
    mapreduce(o -> o', vcat, ops; init = fill(0.0, 0, length(ops[1]))) |>
        plot_opinions
end    

### plot_raster_graph
colors = Colors.range(Colors.colorant"red",
                      stop = Colors.colorant"green",
                      length = 100);

function modify_viz_raster(state::Person, id, _)
    pos = first(neighborstates(sim, id, CurrentLocation, Location)).pos
    Dict(:node_color => colors[Int(ceil(state.opinion * 100))],
         :node_size => 20,
         :node_pos => pos)
end

function modify_viz_raster(state::Location, id, vp)
    num_persons = num_edges(vp.sim, id, CurrentLocation)
    (color, size) = if num_persons > 0
        nstates = neighborstates(vp.sim, id, CurrentLocation, Person)
        opinions = map(p -> p.opinion, nstates)
        identical_opinions = all(x -> x == first(opinions), opinions)
        (identical_opinions ? :purple : :blue, 5 + 4 * length(nstates))
    else
        (:black, 5)
    end

    Dict(:node_marker => :rect,
         :node_color => color,
         :node_size => size,
         :node_pos => state.pos)
end

function modify_viz_raster(_, from, to, vp)
    if from == clicked_agent(vp) || to == clicked_agent(vp)
        Dict(:edge_width => 1,
             :arrow_size => 10)
    else
        Dict(:edge_width => 0.2,
             :arrow_size => 0)
    end
end

function plot_raster_graph(sim)
    vp = create_graphplot(sim;
                          edgetypes = [ Reachable, CurrentLocation, LogRedraw ],
                          update_fn = modify_viz_raster,
                          pos_jitter = [ Person => 0.6 ],
                          edge_plottype=:beziersegments)
    Makie.Colorbar(figure(vp)[:, 2]; colormap = colors)
    resize!(figure(vp), 900, 800)
    figure(vp)
end
