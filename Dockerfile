FROM bioconductor/bioconductor_docker:RELEASE_3_17

ARG aenmd_pack=aenmd_0.3.9.tar.gz
ARG aenmd_dat_pack=aenmd.data.gencode.v43_0.0.3.tar.gz

#- install R dependencies
RUN R -e 'BiocManager::install("dplyr")'    	 			        && \
    R -e 'BiocManager::install("GenomicRanges")' 	 		        && \
    R -e 'BiocManager::install("Biostrings")' 	 		            && \
    R -e 'BiocManager::install("triebeard")' 	 		            && \
    R -e 'BiocManager::install("future")' 	 		                && \
    R -e 'BiocManager::install("GenomeInfoDb")' 	 		        && \
    R -e 'BiocManager::install("janitor")' 	 		                && \
    R -e 'BiocManager::install("parallel")' 	 		            && \
    R -e 'BiocManager::install("pbapply")' 	 		                && \
    R -e 'BiocManager::install("purrr")' 	 		                && \
    R -e 'BiocManager::install("R.utils")' 	 		                && \
    R -e 'BiocManager::install("VariantAnnotation")' 	 		    && \
    R -e 'BiocManager::install("vcfR")' 	 		                && \
    R -e 'BiocManager::install("BSgenome.Hsapiens.UCSC.hg38")' 	 	&& \
    R -e 'BiocManager::install("BSgenome.Hsapiens.NCBI.GRCh38")' 	&& \
    R -e 'BiocManager::install("BSgenome.Hsapiens.UCSC.hg19")'

#- get local files
RUN mkdir -p /aenmd/dat
RUN mkdir -p /aenmd/src
COPY ./dat/$aenmd_pack     /aenmd/dat
COPY ./dat/$aenmd_pack     /aenmd/dat
COPY ./src/aenmd_cli.R     /aenmd/src

#-  install aenmd
RUN R -e 'BiocManager::install("here")'                     && \
    R -e 'BiocManager::install("AnnotationFilter")'         && \
    R -e 'BiocManager::install("argparse")'                 && \
    R -e 'install.packages("/aenmd/dat/'$aenmd_dat_pack'")' && \
    R -e 'install.packages("/aenmd/dat/'$aenmd_pack'")'     && \
    rm /aenmd/dat/$aenmd_dat_pack /aenmd/dat/$aenmd_pack    #- dont need them any more

#- switch to non-root user
RUN groupadd -g 10013 aenmd && \
    useradd -m -u 10017 -g aenmd aenmd && \
    chown -R aenmd:aenmd /aenmd
USER aenmd:aenmd

#- clean-up'## clean up
apt-get clean
apt-get autoremove -y
apt-get autoclean -y
rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/aenmd/src/aenmd_cli.R"]

