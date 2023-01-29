## `aenmd_cli` Annotating escape from nonsense-mediated decay

This repository contains a simple **command line interface** for the `aenmd` **R package** available [at this repository](), so that annotation of human genetic variant with (predicted) escape from nonsense-mediated decay can be run without interacting with the  `R programming language`. We also provide a Dockerfile (and image) for ease of use.

### Quickstart with docker
```
#- get set up
$ git clone kostkalab/aenmd_cli
$ docker pull kostkalab/aenmd_cli

#- run aenmd_cli via shell script
$ cd aenmd_cli
$ ./docker_aenmd_cli.sh -i /my/input/file.vcf -o /my/output/file.vcf

#- we actually only need the shell script from the github repository
$ cp docker_aenmd_cli.sh ~ && cd ..
$ rm -rf aenmd_cli
$ cd 
$ ./docker_aenmd_cli.sh -i /my/input/file.vcf -o /my/output/file.vcf
```

What if I want to use `podman`?

```
$ ./docker_aenmd_cli.sh -p -i /my/input/file.vcf -o /my/output/file.vcf
```


### Running `aenmd_cli` without docker

### Notes about `aenmd_cli` with docker

#### -Note: This git repository is not necessary to run `aenmd_cli`:
```
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

#### -Note: Memory can be an issue. 
Eespecially when running docker/podman/etc. inside a virtual machine (e.g., on a Mac using `podman` [(see here)](https://podman.io/getting-started/installation)). Below is an example how to increase memory size available to podman. 
```
#-
$ podman machine stop
$ podman machine inspect | grep Memory
$ podman machine set -m=8192
$ podman machine inspect | grep Memory
$ podman machine start

```

#### -Note: Passing input/output files can be un-intuitive.
That is especially then when `docker` or `podman` are running inside a virtual machine as well. Below again a podman example
```
#- run mount a project directory for input/output running podman
#  we assume input:   /my/project/directory/input.vcf
#            output:  /my/project/directory/output.vcf

#- need to initialize podman machine so it can access the project directory
$ podman machine init -v /my/project/directory:/mnt/MYVOLUME

#- then pass input/output files through to podman (again)
$ ./docker_aenmd_cli.sh -r "podman run"         \
                        -I /mnt/MYVOLUME        \
                        -O /mnt/MYVOLUME        \
                        -i /path/to/input.vcf   \
                        -o /path/to/output.vcf

#- or directly (instead of the previous command, still need podman machine init)
#  note the we run docker/podman here bind-mounting the directory of the VM
$ podman run                                                                    \
   --mount type=bind,src=/mnt/MYVOLUME/INPUT.vcf,dst=/aenmd/input/input.vcf     \       
   --mount type=bind,src=/mnt/MYVOLUME/OUTPUT.vcf,dst=/aenmd/output/output.vcf  \   
   aenmd_cli                                                                    \
   -i /aenmd/input/input.vcf                                                    \
   -o /aenmd/output/output.vcf 

#- Note the docker_aenmd_cli.sh script also works with different directories for 
#  input and output, provided they are accessible to podman/docker
```

