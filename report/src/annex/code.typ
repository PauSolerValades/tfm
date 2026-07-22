#import "../utils.typ": *

This section describes which rellevant repositories 
== `des-ctic`

The `des-ctic` @soler2025desctic code repository has the simulation engine, the cascade construction and the dataset generation from the simulation traces, as well as a pipeline to schedule and coordinate all three projects. It has the following structure:
1. `bskysim/`: contains the simulation engine, as well as the configuration files used for all the runs. Coded with Zig 0.16.0.
2. `cascade-construction/`: from a Job with several runs, construct all the cascades in all runs and stores them into a `.tsv` files. Coded with Zig 0.16.0
3. `dataset-creation`: from the traces and the `cascades.tsv` file constructs nine distinct datasets to analyze the simulation. It uses DuckDB with a Go program to execute it, as well as just a Go program for all the cascades datasets.
4. `build.zig`: a Zig Build System implementation that orchestrates the pipeline. Allows for sequential execution of the three subprojects described as well as recompilation if needed. It's an equivalent to the use of `make` #todo[cite] but written in Zig.

Additionally, there is a `python-utils` directory, which contains some handy quickly coded scripts:
1. `validate-trace.py`: used as a test when introducing big changes in the simulation, it tests basic rules and properties the traces must mantain.
2. `paquet_to_bin.py`: given the samples datasets from the topology #todo[cite from the document] converts it into a binary format with monotonic user id.

It has dependencies with the `bsky-ds` and `distributions` repositories.

== `bskysim-data-analysis`

The `bsky-data-analysis` contains all the codes needed to extract and analyze the datasets output of the `des-ctic` repository.

#todo[redo when it's done]

== `bsky-data-analysis`

#todo[Redo when it's done]


== `bsky-topology-reconstruction`

Contains the code used to generate the running topology of the simulation.
#todo[revise, i dont even remeber the fuck is in that repo]


== `bsky-ds`

The `bsky-ds` repository contains all the data structures used by the simulation
described in the Design and Implementation sections (see #todo[cite]). It is a Zig
library exposing a module named `ds`, with the following structure:

1. `src/heap.zig`: binary heap (`Heap`) and $d$-ary heap (`DaryHeap`). 
2. `src/segmented_list.zig`: `SegmentedMultiArrayList` --- an array with a fixed number of rows but growable columns, backed by `MultiArrayList`.
3. `src/paged_bitset.zig`: `PagedBitSet` --- a matrix with fixed rows and growable columns, backed by `DynamicBitSetUnmanaged`.


== `distributions`

The `distributions` #todo[cite] repository implements all the distributions used in this program, and it's a public use released library.

== `des-ctic-progress`

The `des-ctic-progress` #todo[cite] contains the distinct versions of the simulation as described in section #todo[cite].



