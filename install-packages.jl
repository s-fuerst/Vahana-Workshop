using Pkg

for p in [ :About, :BenchmarkTools, :DataFrames, :GraphMakie, :Infiltrator,
        :OhMyREPL, :StatsBase, :Vahana, :WGLMakie ]
    Pkg.add(string(p))
end
