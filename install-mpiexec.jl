# this script is assuming that it is run on a JuliaHub instance

using MPI
MPI.install_mpiexecjl(force=true)
symlink("/home/jrun/data/.julia/bin/mpiexecjl", "/home/jrun/data/code/Vahana-Workshop/mpiexec")
