#!/bin/sh

#- extract 1k variants from clinvar to have a vcf file to work with.
#-------------------------------------------------------------------

#- download clinvar data
#  fimxe: use BiocFileCache 
wget https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/archive_2.0/2022/clinvar_20221211.vcf.gz
wget https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/archive_2.0/2022/clinvar_20221211.vcf.gz.tbi

#- use R and the  vcfR package to extract a small sample
cat <<EOF | R --slave 
vcf <- vcfR::read.vcfR("./clinvar_20221211.vcf.gz")
set.seed(2353)
ind <- sample(dim(vcf)[1],1000L)
vcfR::write.vcf(vcf[ind,],file="./vcffile.vcf.gz")
EOF

#- clean up
rm clinvar_20221211.vcf.gz clinvar_20221211.vcf.gz.tbi
[[ ! -e ../dat ]] && mkdir ../dat 
mv ./vcffile.vcf.gz ../dat/


