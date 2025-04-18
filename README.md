# Vahana-Workshop

A self-paced, hands-on workshop for agent-based modeling and high-performance simulation with [Vahana.jl](https://github.com/s-fuerst/Vahana.jl).

This repository was originally created for the [Scaling Complexity Workshop](https://indico.kit.edu/event/4657/), but can be freely used for independent study.

## Repository Structure

| Directory       | Contents                                                                         |
|-----------------|----------------------------------------------------------------------------------|
| `presentation/` | Workshop slides (PDFs) and an introductory Julia Jupyter Notebook (`.ipynb`)     |
| `exercises/`    | All programming exercises; each file starts with a description of the assignment |
| `solutions/`    | Sample solutions for all exercises                                               |
| `support/`      | helper functions for simulation result visualization                             |

## Getting Started

1. **Install Julia**
    - See [Installing Julia](https://julialang.org/install/). Alternativly you can use JuliaHub, as described in `presentation/setup.pdf`.

2. **Clone This Repository**
    ```bash
    git clone https://github.com/s-fuerst/Vahana-Workshop.git
	```
	
3. **Install needed packages** (may take several minutes to complete)	
    ```bash
    cd Vahana-Workshop
	julia --project install-packages.jl
    ```

## How to Use This Workshop

1. **(Optional) Review Presentations**
    - The `presentation/` directory contains:
		- `00-julia-basics.ipynb`: Concise Julia introduction—intended for participants who know how to program but are new to Julia
        - `setup.pdf`: Instructions for running the workshop by using JuliaHub for a fully browser-based experience (no local install needed). 
        - `vahana-part1.pdf` to `vahana-part3.pdf`: Slides matching the main sessions and exercises
    - Slides do NOT contain the programming tasks, but do offer theoretical context and step-by-step guidance for Vahana.jl usage

2. **Do the Exercises**
    - In `exercises/` you’ll find all tasks as individual `.jl` files.
    - Each file starts with an assignment, describing the modeling or coding challenge.
    - Work through the files in order. Each builds on the previous (numbered by session).

3. **Check Solutions (if needed)**
    - The `solutions/` directory contains fully worked solutions for all exercises, aligned by session and task number. 


## Acknowledgment

<img src="./NHR-logo.png" alt="NHR Logo" width="180" align="left" style="margin-right: 20px;">

This material was developed for the [Scaling Complexity Workshop](https://indico.scc.kit.edu/event/3649/), Zuse Institute Berlin, December 2-3, 2024, and funded by [NHR Alliance](https://www.nhr-verein.de/en).

For researchers at German universities interested in running
large-scale Vahana simulations, the NHR Alliance offers access to
high-performance computing resources through several project
categories.

Of particular interest to those new to HPC is the **NHR-Starter**
category. This one-time opportunity is designed for researchers
without prior experience in HPC resource applications. For more
information about NHR resource allocation and application procedures,
visit the [NHR website](https://www.nhr-verein.de/rechnernutzung).


<br clear="left"/>
