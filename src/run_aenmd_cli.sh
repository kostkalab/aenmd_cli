#!/bin/bash

#==========================================
# shell script to comfortably run aenmd_cli
# from inside its docker container.
#==========================================

#- option parsin (getopts)
#-------------------------

OPTIND=1

bare=""
ipt_file=""
opt_file=""
opt_vm_dir=""
ipt_vm_dir=""
run_cmnd="docker run"
verbose=0
dist_3="50"
dist_5="150"
USAGE="
usage: $0 [options]

Runs aenmd_cli inside a docker container.
Short option are for interacting with this script, related to passing 
input/output to aenmd_cli.R. Actual options to aenmd_cli.R are long options:

-b PATH    don't use docker, use existing aenmd installation. PATH points 
           to the directory containig the aenmd_cli.R script.
-p         use podman instead of docker
-i FILE    input file. If -I is given, relative to the directory given there
-I DIR     if podman/docker run inside a VM, directory in the VM where
           input file is located
-o FILE    output file. If -O given, relative to the directory given there
-O DIR     if podman/docker run inside a VM, directory in the VM where
           output file is located
-v         print progress
-5 NUM     Distance (in bp) for CSS-proximal NMD escape rule (5' rule).
           That is, PTCs within NUM bp downstream of the CSS (5' boundary) 
           are predicted to escape NMD. If omitted: 150
-3 NUM     Distance (in bp) for penultimate exon NMD escape rule (3' rule).
           That is, PTCs within NUM bp upstream of the penultimate exon 
           3'-end are predicted to escape NMD. If omitted: 50
"

while getopts "h?vpb:I:i:o:O:3:5:" opt; do
  case "$opt" in
    h|\?)
      printf "%s\\n" "$USAGE"
      exit 0
      ;;
    v)  verbose=1
      ;;
    b)  bare=$OPTARG
        [[ -z "$bare" ]] && bare="./"
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
    3)  dist_3=$OPTARG
      ;;
    5)  dist_5=$OPTARG
      ;;
  esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift


#- don't overwrite existing results
#----------------------------------
if [[ -f "$opt_fle" ]]; then
    echo "Output file $opt_fle exists. Not overwriting it. Exiting."
    exit 0
fi

#- if we don't use a container
#-----------------------------
if [[ ! -z "$bare" ]]; then
  $bare/aenmd_cli.R     \
          -i $ipt_file  \
          -o $opt_file  \
          -5 $dist_5    \
          -3 $dist_3

  exit 0
fi

#- if we are running docker inside a vm
#-------------------------------------- 
#  vm_{ipt,opt}_file default to the "regular" input/output files
vm_opt_file=$opt_file
vm_ipt_file=$ipt_file
[[ ! -z $vm_opt_dir ]] && vm_opt_file="$vm_opt_dir/$opt_file"
[[ ! -z $vm_ipt_dir ]] && vm_ipt_file="$vm_ipt_dir/$ipt_file"

#- establish output
#------------------ 
touch $opt_file      #- otherwise we get a bind-mount error
chmod a+rw $opt_file #- need write access for aenmd 

#- for each type of output (.vcf, .vcf.gz, .vcf.bgz)
#  we run aenmd_cli.R in docker a bit differently:
#---------------------------------------------------
case "$opt_file" in
*.vcf.gz )
        cnt_opt_file="output.vcf.gz"
        cnt_ipt_file="input"."${ipt_file##*.}"
        $run_cmnd                                                                       \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file    \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file  \
          aenmd_cli                                                                          \
          -i /aenmd/input/$cnt_ipt_file                                                      \
          -o /aenmd/output/$cnt_opt_file                                                     \
          -5 $dist_5                                                                         \
          -3 $dist_3
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
        $run_cmnd                                                                                      \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file                   \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file                 \
          --mount type=bind,readonly=false,src=${vm_opt_file%*.bgz},dst=/aenmd/output/${cnt_opt_file%*.bgz} \
          --mount type=bind,readonly=false,src=$vm_opt_file.tbi,dst=/aenmd/output/$cnt_opt_file.tbi         \
          aenmd_cli                                                                                         \
          -i /aenmd/input/$cnt_ipt_file                                                                     \
          -o /aenmd/output/$cnt_opt_file                                                                    \
          -5 $dist_5                                                                                        \
          -3 $dist_3
        chmod a-w $opt_file.tbi
        rm ${opt_file%*.bgz} #- wtf? for some reason this file keeps hanging out
        ;;
*.vcf )
        cnt_opt_file="output.vcf"
        cnt_ipt_file="input"."${ipt_file##*.}"
        $run_cmnd                                                                       \
          --mount type=bind,readonly=true,src=$vm_ipt_file,dst=/aenmd/input/$cnt_ipt_file    \
          --mount type=bind,readonly=false,src=$vm_opt_file,dst=/aenmd/output/$cnt_opt_file  \
          aenmd_cli                                                                          \
          -i /aenmd/input/$cnt_ipt_file                                                      \
          -o /aenmd/output/$cnt_opt_file                                                     \
          -5 $dist_5                                                                         \
          -3 $dist_3
        ;;
*)
        # usupported file type
        echo "only supporting vcf output; exiting"
        exit 0
        ;;
esac

#- remove write access from output
#---------------------------------
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
