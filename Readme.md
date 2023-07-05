
## aenmd_cli

### Command line interface for the aenmd R package

- [Introduction](#introduction)
- [Quickstart with docker](#quickstart-with-docker)
- [Using the CLI without docker](#running-aenmd_cli-without-docker)
- [Notes](#notes-about-aenmd_cli-with-docker)
    - [Interacting with the container directly](#running-aenmd_clir-directly)
    - [Input/output when docker is running in a VM](#inputoutput-files-when-docker-is-running-in-a-virtual-machine)
    - Example: `aenmd_cli` in vanilla Ubuntu 22.04
#### Introduction

This repository contains a simple command line interface (CLI) for the `aenmd` `R` package available [at this repository](https://github.com/kostkalab/aenmd). `aenmd` annotates variant/transcript pairs with premature termination codons with predicted escape from nonsense-mediated decay.

With the CLI this can be done  without interacting with the  `R programming language` directly, and `aenmd` can be integrated into processing workflows more easily. We also provide a Dockerfile (and image).

#### Quickstart with docker / podman

Here we assume access to docker is configured and a vcf file `/my/input/file.vcf` is to be analyzed using `aenmd`. Output is to be written to `/my/output/file.vcf`.

```bash
#- download docker image
docker pull ghcr.io/kostkalab/aenmd_cli:v0.3.7

#- check if the aenmd_cli image has been installed
docker image ls | grep aenmd_cli
#- output should look something like:
#  ghcr.io/kostkalab/aenmd_cli  v0.3.7    ...

#- download script to run aenmd
wget https://raw.githubusercontent.com/kostkalab/aenmd_cli/master/src/run_aenmd_cli.sh
chmod u+x ./run_aenmd_cl.sh
#- download input file (example vcf)
wget https://raw.githubusercontent.com/kostkalab/aenmd/master/inst/extdata/clinvar_20221211_noinfo_sample1k.vcf.gz
gunzip clinvar_20221211_noinfo_sample1k.vcf.gz

#- run aenmd_cli container via shell script
./run_aenmd_cli.sh -i ./clinvar_20221211_noinfo_sample1k.vcf.gz -o aenmd_output_file.vcf
```
Since we are using docker, we only need one script from the repository.
We can clean up the rest.

```bash
#- we actually only need the shell script from the github repository
cp ./src/run_aenmd_cli.sh ~ && cd .. #- copy to where scripts are kept
rm -rf aenmd_cli
cd 
./run_aenmd_cli.sh -i /my/input/file.vcf -o /my/output/file.vcf
```

Podman is also an option

```bash
#- use podman instead of docker
./run_aenmd_cli.sh -p -i /my/input/file.vcf -o /my/output/file.vcf
#- get help
./run_aenmd_cli.sh -h
# 
# Runs aenmd_cli inside a docker container.
# Short option are for interacting with this script, related to passing 
# input/output to aenmd_cli.R. Actual options to aenmd_cli.R are long options:
# 
# -b PATH    don't use docker, use existing aenmd installation. PATH points 
#            to the directory containig the aenmd_cli.R script.
# -p         use podman instead of docker
# -i FILE    input file. If -I is given, relative to the directory given there
# -I DIR     if podman/docker run inside a VM, directory in the VM where
#            input file is located
# -o FILE    output file. If -O given, relative to the directory given there
# -O DIR     if podman/docker run inside a VM, directory in the VM where
#            output file is located
# -v         print progress
# -5 NUM     Distance (in bp) for CSS-proximal NMD escape rule (5' rule).
#            That is, PTCs within NUM bp downstream of the CSS (5' boundary) 
#            are predicted to escape NMD. If omitted: 150
# -3 NUM     Distance (in bp) for penultimate exon NMD escape rule (3' rule).
#            That is, PTCs within NUM bp upstream of the penultimate exon 
#            3'-end are predicted to escape NMD. If omitted: 50
```

#### Using `aenmd_cli` without docker

Of course it is possible to use the CLI without docker. 
In this case, it will make use of an existing installation of `aenmd` - see [its repository]() for details.
Also, it is not necessary to pull the docker image.
There are two ways to use `aenmd_cli` without docker:

##### Using `run_aenmd_cli.sh` without docker

This is essentially the same as discussed above, just with th `-b PATH` option selected.

```bash
#- Don't use a container with the -b option
#  (here we assume run_aenmd_cli.sh is in the current directory; i.e., PATH = './')
./run_aenmd_cli.sh -b './' -i /my/input/file.vcf -o /my/output/file.vcf
```

##### Using `aenmd_cli.R`

Alternatively, we can forgo `run_aenmd_cli.sh` and run `aenmd_cli.R` directly; for example:

```bash
./aenmd_cli.R -i /my/input/file.vcf  \
              -o /my/output/file.vcf \
              -3 50                  \
              -5 150                 \
```

#### Notes about `aenmd_cli` with docker

##### Running `aenmd_cli.R` directly:

Running `run_aenmd_cli.sh` is supposed to make accessing the container supplying `aenmd_cli.R` more intuitive, but it is not necessary:

```bash
#- We can interact with the container directly.
#  (we only need the docker image here) 
$ docker pull kostkalab/aenmd_cli
$ docker run docker_aenmd_cli --help
$ docker run                                                                              \
    --mount type=bind,readonly=true,src=/my/input/file.vcf,dst=/aenmd/input/input.vcf     \
    --mount type=bind,readonly=false,src=/my/output/file.vcf,dst=/aenmd/output/output.vcf \
    aenmd_cli                                                                             \
    -i /aenmd/input/input.vcf                                                             \
    -o /aenmd/output/output.vcf
```

##### Input/output files when docker is running in a virtual machine

Sometimes docker/podman run in virtual machines (e.g., Mac).
This means that that input/output files need to be passed between three entities:

`host OS <-> VM <-> Container with aenmd`

For example, on the host OS we have input/output files as

```bash
host OS:
--------
input  = /my_proj/input/file.vcf
output = /my_proj/output/file.vcf
```

Which could then accessible under a different path in the VM.
For example, we might have been using `podman` like

```bash
#- make /my_proj accessible in podman
podman machine init -v /my_proj:/mnt/MYPROJ
```
Then input/output files in the VM are 

```bash
VM
--
input  = /mnt/MYPROJ/input/file.vcf
output = /mnt/MYPROJ/output/file.vcf
```

In this case, we need to inform `aenmd_cli` about the files' names in the VM:

```bash
#- Paths when docker/podman run inside a VM
$ ./run_aenmd_cli.sh -p                  \
                     -I /mnt/MYPROJ      \
                     -O /mnt/MYPROJ      \
                     -i /input/file.vcf  \
                     -o /output/file.vcf
```

This will essentially result in the following command being executed:

```bash
podman run                                                                                       \
   --mount type=bind,readonly=true,src=/mnt/MYPROJ/input/file.vcf,dst=/aenmd/input/input.vcf     \       
   --mount type=bind,readonle=false,src=/mnt/MYPROJ/output/file.vcf,dst=/aenmd/output/output.vcf \   
   aenmd_cli                                                                                     \
   -i /aenmd/input/input.vcf                                                                     \
   -o /aenmd/output/output.vcf 
```

##### Example: setting up aenmd_cli using vanilla Ubuntu 22.04

Here we do a comprehensive setup of `aenmd_cli` starting with a vanilla Ubuntu 22.04. We have been using `podman machine` on a Mac (using 8 GB of RAM), but we hope by starting with a generic setup these instructions will be broadly useful.

* Start Ubuntu 22.04
This is not strictly necessary, we just do this to achieve a controlled environment. Note that we will be root user (inside the container) after the following command:
```
#- run ubuntu kinetic (privileged, since we'll run podman inside)
$ podman run    --interactive           \
                --tty                   \
                --name aemnd_container  \
                --privileged            \
                ubuntu:22.04
```

* Next, we install some necessary tools:
```
$ apt-get -y update
$ apt-get -y install podman
$ apt-get -y install git
$ apt-get -y install wget
```

* Next we create and change into a "regular" user named "tst"
```
$ adduser --disabled-password --gecos "" tst
$ su tst
$ cd
``` 

* Next, we pull the `aenmd_cli` container image
```
$ podman pull ghcr.io/kostkalab/aenmd_cli:v0.3.7
$ podman image ls | grep aenmd_cli #- should find it
```

* Next, we get the script to run `aenmd_cli` comfortably from the command line
```
$ wget https://raw.githubusercontent.com/kostkalab/aenmd_cli/master/src/run_aenmd_cli.sh
$ chmod u+x ./run_aenmd_cli.sh
```

* Next, we download an example `vcf` file from the `aenmd` GitHub repository
```
$ wget https://raw.githubusercontent.com/kostkalab/aenmd/master/inst/extdata/clinvar_20221211_noinfo_sample1k.vcf.gz
```

* Finally, we run `aenmd` using the container image we pulled from the GitHub container registry:
```
$ ./run_aenmd_cli.sh -p -i ./clinvar_20221211_noinfo_sample1k.vcf.gz -o aenmd_output_file.vcf
```