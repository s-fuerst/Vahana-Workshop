using Pkg

for p in [ :About, :BenchmarkTools, :Colors, :DataFrames, :GraphMakie, :Infiltrator,
        :MPI, :OhMyREPL, :StatsBase, :Vahana, :WGLMakie ]
    Pkg.add(string(p))
end
