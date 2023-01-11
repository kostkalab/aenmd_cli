#!/bin/bash

#==========================================
# shell script to comfortably run aenmd_cli
# from inside its docker container.
#==========================================

#- use getopt for argument parsing
#---------------------------------
OPTIND=1

# Initialize our own variables:
ipt_file=""
opt_file=""
opt_vm_dir=""
ipt_vm_dir=""
run_cmnd="docker run"
verbose=0

USAGE="
usage: $0 [options]

Runs aenmd_cli inside a docker container.

-p         use podman instead of docker
-I DIR     if podman/docker run inside a VM, directory in the VM where
           input file is located
-i FILE    input file. If -I is given, relative to the directory given there.
-O DIR     if podman/docker run inside a VM, directory in the VM where
           output file is located
-o FILE    output file. If -O given, relative to the directory given there.
-v         print progress
"

while getopts "h?vpI:i:o:O:" opt; do
  case "$opt" in
    h|\?)
      echo $USAGE
      exit 0
      ;;
    v)  verbose=1
      ;;
    O)  vm_opt_dir=$OPTARG
      ;;
    o)  opt_file=$OPTARG
      ;;
    I)  vm_ipt_dir=$OPTARG
      ;;
    i)  ipt_file=$OPTARG
      ;;
    p)  run_cmnd="podman run"
      ;;
  esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift


#- don't overwrite existing results:
if [[ -f "$opt_fle" ]]; then
    echo "Output file $opt_fle exists. Not overwriting it. Exiting."
    exit 0
fi

#- if we are running docker inside a vm; 
#  vm_{ipt,opt}_file default to the "regular" input/output files
vm_opt_file=$opt_file
vm_ipt_file=$ipt_file
[[ ! -z $vm_opt_dir ]] && vm_opt_file="$vm_opt_dir/$opt_file"
[[ ! -z $vm_ipt_dir ]] && vm_ipt_file="$vm_ipt_dir/$ipt_file"

#- coordinate output 
touch $opt_file      #- otherwise we get a bind-mount error
chmod a+rw $opt_file #- need write access for aenmd 

case "$opt_file" in
*.vcf.gz )
        cnt_opt_file="output.vcf.gz"
        cnt_ipt_file="input"."${ipt_file##*.}"
        $run_cmnd                                                                            \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file    \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file  \
          aenmd_cli                                                                          \
          -i /aenmd/input/$cnt_ipt_file                                                      \
          -o /aenmd/output/$cnt_opt_file
        ;;
*.vcf.bgz )
        #- here we need to also take care of the tabix index, automatically created by aenmd_cli.R
        #- and that we need to be able to write to the vcf without the bgz extension as well.
        touch $opt_file.tbi
        chmod a+w $opt_file.tbi
        touch ${opt_file%*.bgz}
        chmod a+w ${opt_file%*.bgz}
        cnt_opt_file="output.vcf.bgz"
        cnt_ipt_file="input"."${ipt_file##*.}"
        $run_cmnd                                                                                           \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file                   \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file                 \
          --mount type=bind,readonly=false,src=${vm_opt_file%*.bgz},dst=/aenmd/output/${cnt_opt_file%*.bgz} \
          --mount type=bind,readonly=false,src=$vm_opt_file.tbi,dst=/aenmd/output/$cnt_opt_file.tbi         \
          aenmd_cli                                                                                         \
          -i /aenmd/input/$cnt_ipt_file                                                                     \
          -o /aenmd/output/$cnt_opt_file
        chmod a-w $opt_file.tbi
        rm ${opt_file%*.bgz} #- wtf? for some reason this file keeps hanging out
        ;;
*.vcf )
        cnt_opt_file="output.vcf"
        cnt_ipt_file="input"."${ipt_file##*.}"
        $run_cmnd                                                                            \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file    \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file  \
          aenmd_cli                                                                          \
          -i /aenmd/input/$cnt_ipt_file                                                       \
          -o /aenmd/output/$cnt_opt_file
        ;;
*)
        # usupportef file type
        echo "only supporting vcf output; exiting"
        exit 0
        ;;
esac

#- remove write access from output
chmod a-w $opt_file

#$run_cmnd                                                                          \
#    --mount type=bind,readonly=true,src=$ipt_file,dst=/aenmd/input/$my_ipt_file    \
#    --mount type=bind,readonly=false,src=$opt_file,dst=/aenmd/output/$my_opt_file  \
#    aenmd_cli                                                                      \
#    -i /aenmd/$my_ipt_file                                                         \
#    -o /aenmd/$my_opt_file


#./docker_aenmd_cli.sh -r "podman run"
#                   -i /mnt/myvol/gnomad-chr21_sample.vcf
#                   -o /mnt/myvol/tst.vcf

#./docker_aenmd_cli.sh -r "podman run" -I /mnt/myvol -i gnomad-chr21_sample.vcf -O /mnt/myvol -o ./tst.vcf.bgz
