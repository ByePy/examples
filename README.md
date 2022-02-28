# ByePy – Examples

_Say goodbye to python functions!_

## Usage

1. create a virtual python environment with `requirements.txt` 
2. setup a postgres instance with a database called `postgres`
3. create a local copy of `.env.example` called `.env` and fill in the details
4. run `python <example/example.py>` to your hearts content

## Examples

The following is a list of all examples provided in this
repository. All example prefix with `TPC-H` require a TPC-H
instance to run. Refer too the [following section](#tpc-h) for
more information.

| Example          | Directory    |
|:---------------- |:------------ |
| Barnes-Hut       | `barnes_hut` |
| Marching Sqaures | `march`      |
| TPC-H Margins    | `margin`     |
| Markov Robot     | `markov`     |
| TPC-H Packing    | `packing`    |
| TPC-H Savings    | `savings`    |
| Simple VM        | `vm`         |

## TPC-H

Some examples require a TPC-H [^TPCH] [^TPCHkit] instance to work. This
repositoy provides a small one (scaling factor `sf = 0.01`) and a scripts to
setup you DB with it. Simply run the script `.TPCH/load.sh` and all necessary
setup will be performed automatically.

[^TPCH]: http://www.tpc.org/tpch
[^TPCHkit]: http://github.com/gregrahn/tpch-kit