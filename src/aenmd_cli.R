#!/usr/bin/env Rscript

suppressPackageStartupMessages(library("methods"))
suppressPackageStartupMessages(library("argparse"))
suppressPackageStartupMessages(library("cli"))

options(rlang_backtrace_on_error = "none")


argmts <- ArgumentParser()

#- from argparse package:
#-------------------------
# specify our desired options 
# by default ArgumentParser will add an help option 

argmts$add_argument("--verbose", action="store_true", default=TRUE,
    help="Print extra output [default]")
argmts$add_argument("--quietly", action="store_false", 
    dest="verbose", help="Print minimal output")
argmts$add_argument("-i", "--input", type="character", default=NULL, 
    help="Input VCF file")
argmts$add_argument("-o", "--output", type="character", default=NULL, 
    help="Output VCF file")
argmts$add_argument("-5","--dist_5p", type="integer", default=150, 
    help="Distance for CSS-proximal NMD escape rule")
argmts$add_argument("-3", "--dist_3p", type="integer", default=50, 
    help="Distance for penultimate exon NMD escape rule")



# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults, 
clargs <- argmts$parse_args()


#- check if we find input file (early exit otherwise)
#----------------------------------------------------
if(!file.exists(clargs$input)){
    cli_abort(paste("Cannot find input file: ", style_underline(clargs$input)))
}

#- check if we can write to directory of output file (early exit otherwise)
#--------------------------------------------------------------------------
ofdir <- dirname(clargs$output)
if( ! (R.utils::fileAccess(ofdir) == 0) ){
    cli_abort(paste("Cannot write to output file directory: ", style_underline(ofdir)))
}
rm(ofdir)


#- load aenmd package
#--------------------
# print some progress messages to stderr if "quietly" wasn't requested
if ( clargs$verbose ) { 
    message("Loading aenmd package and annotations ...", appendLF = FALSE)
} 
suppressPackageStartupMessages(library("aenmd"))
if ( clargs$verbose ) { 
    cli_text("done.")
} 

#- read input VCF file
#---------------------
if ( clargs$verbose ) { 
    message("Reading input file: ", style_underline(clargs$input), " ...",  appendLF = FALSE)
} 

#- read in VCF without the genotypes
vcf      <- VariantAnnotation::readVcf(clargs$input, param = VariantAnnotation::ScanVcfParam(geno=NA))
rr_c     <- SummarizedExperiment::rowRanges(vcf)
rr_c$sky <- paste0( GenomicRanges::seqnames(rr_c) |> as.character(), ':',  GenomicRanges::start(rr_c))
vcf      <- VariantAnnotation::expand(vcf)

#- split ranges and info
vcf_rng <- SummarizedExperiment::rowRanges(vcf)
colnames( vcf_rng |> S4Vectors::mcols() ) <- vcf_rng |> S4Vectors::mcols() |> 
                                                        colnames() |> janitor::make_clean_names()
#- do seqlevelstype by hand
tmp <- GenomeInfoDb::seqnames(vcf_rng) |> S4Vectors::runValue() |> as.character()|>   stringr::str_detect("^chr")
if(any(tmp)){
    gn <- GenomeInfoDb::genome(vcf_rng)
    GenomeInfoDb::genome(vcf_rng) <- NA
    GenomeInfoDb::seqlevelsStyle(vcf_rng)  <- 'NCBI'
    GenomeInfoDb::genome(vcf_rng) <- gn
    rm(gn)
}
vcf_rng$key <- aenmd:::make_keys(vcf_rng)
vcf_ifo <- VariantAnnotation::info(vcf)
if ( clargs$verbose ) { 
    cli_text("done.")
} 


#- run NMD escape prediction
#---------------------------
if ( clargs$verbose ) { 
    message("Filtering variants: ", " ...",  appendLF = FALSE)
} 
ipt <- aenmd::process_variants(vcf_rng, verbose = FALSE)
if(length(ipt) == 0){
    cli_alert('Input file does not contain variants passing the filtering process. No ouput file will be created. Quitting.')
    q(save = FALSE, runLast = FALSE)
}
if ( clargs$verbose ) { 
    cli_text("done.")
} 

if ( clargs$verbose ) { 
    message("Annotating predicted escape from NMD: ", " ...",  appendLF = FALSE)
} 
opt <- aenmd::annotate_nmd(ipt, rettype = 'gr') |> sort()
if ( clargs$verbose ) { 
    cli_text("done.")
} 


if ( clargs$verbose ) { 
    message("Formatting and writing results: ", " ...",  appendLF = FALSE)
} 
#- aggregate result by variant (i.e., over transcripts)
#------------------------------------------------------
rcol <- c("is_ptc", "is_last", "is_penultimate", "is_cssProximal", "is_single", "is_407plus")
tmp1 <- apply(opt$res_aenmd[,rcol], 1, function(x) paste(as.integer(x), collapse = ":"))
tmp2 <- paste(opt$res_aenmd[,'transcript'],tmp1, sep = "|")
res  <- tapply(tmp2, opt$key, function(x) paste(x, collapse=","))

#- prepare output VCF and write output file
#------------------------------------------
rownames(vcf) <- vcf_rng$key
rownames(vcf_ifo) <- vcf_rng$key
vcf_out <- vcf[names(res)]
ifo_out <- vcf_ifo[names(res),]
ifo_out$aenmd <- res


#- header 
#--------

#- keep track of aenmd version used
v1 <- paste0("aenmd: version ", utils::packageVersion("aenmd"))
v2 <- paste0(ad_get_packagename(), ", version: ", utils::packageVersion(ad_get_packagename()))
v3 <- paste0(v1, " with ",v2, ". Format: ")

#- communicate make-up of info column for aenmd
tmp <- VariantAnnotation::header(vcf_out)
hdr_ifo <- tmp |> VariantAnnotation::info() |> as.data.frame()
desc <- paste(v3, "transcript_id",paste0(rcol, collapse = ":"),sep="|")
hdr_ifo <- rbind(hdr_ifo,c(".", "String", desc))
#- had no info in vcf that was provided
if(nrow(hdr_ifo)==1){
    colnames(hdr_ifo) <- c("Number","Type","Description")
}
rownames(hdr_ifo)[dim(hdr_ifo)[1]] <- 'aenmd'
VariantAnnotation::info(tmp) <- hdr_ifo |> S4Vectors::DataFrame()
VariantAnnotation::header(vcf_out) <- tmp

#- content
VariantAnnotation::info(vcf_out) <- ifo_out

#- determine output type
if(stringr::str_detect(clargs$output,".gz$")){
    of <- gzfile(clargs$output, open = 'wb')
} else {
    of <- file(clargs$output, open = 'wt')
}
if(stringr::str_detect(clargs$output,".bgz$")){
   do_index <- TRUE
   #- need to remove file extension, since writeVCF adds one again
   close(of)
   of <- file(stringr::str_remove(clargs$output,"\\.bgz$"), open = 'wt')
} else {
   do_index <- FALSE
}

#- write output; switch off warnings, otherwise we hear about NULL pointer conversion
VariantAnnotation::writeVcf(vcf_out, filename = of, index = do_index) |> suppressWarnings()
close(of)

if ( clargs$verbose ) { 
    cli_text("done.")
} 





