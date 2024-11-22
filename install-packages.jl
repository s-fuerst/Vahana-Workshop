using Pkg

for p in [ :About, :Accessors, :BenchmarkTools, :DataFrames, :DataFramesMeta,
        :GraphMakie, :Infiltrator, :OhMyREPL, :StatsBase, :Vahana, :WGLMakie ]
    Pkg.add(string(p))
end
