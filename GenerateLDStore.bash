### Script: Generate LDStore LD Matrix files
### Date: 2022-03-25
### Authors: JRIColeman
### Version: 0.2.2022.06.27

#####################################################################################
#####################################################################################
############## INITIALISE OPTIONS AND CHECK REQUIRED INPUTS ARE GIVEN ###############
#####################################################################################
#####################################################################################

## Declare numeric options

declare -i chromosome

## Get command line options

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts :-: OPT; do
    # HT: Adam Katz
    # support long options: https://stackoverflow.com/a/28466267/519360
    if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    case "$OPT" in
	input )    needs_arg; input="$OPTARG" ;;
	inputbed )    needs_arg; inputbed="$OPTARG" ;;
	inputbim )    needs_arg; inputbim="$OPTARG" ;;
	inputfam )    needs_arg; inputfam="$OPTARG" ;;
	inputbgen )    needs_arg; inputbgen="$OPTARG" ;;
	inputbgi )    needs_arg; inputbgi="$OPTARG" ;;
	inputsample )    needs_arg; inputsample="$OPTARG" ;;
	chromosome )    needs_arg; chromosome="$OPTARG" ;;
	start )    needs_arg; start="$OPTARG" ;;
	end )    needs_arg; end="$OPTARG" ;;
	extract )    needs_arg; extract="$OPTARG" ;;
	keep )    needs_arg; keep="$OPTARG" ;;
	samplen )    needs_arg; samplen="$OPTARG" ;;
	threads )    needs_arg; threads="$OPTARG" ;;
	output )    needs_arg; output="$OPTARG" ;;
	inputtype )    needs_arg; inputtype="$OPTARG" ;;
	ldstorepath )    needs_arg; ldstorepath="$OPTARG" ;;
	plinkpath )    needs_arg; plinkpath="$OPTARG" ;;
	bgenixpath )    needs_arg; bgenixpath="$OPTARG" ;;
	qctoolpath )    needs_arg; qctoolpath="$OPTARG" ;;
	??* )          die "Illegal option --$OPT" ;;  # bad long option
	? )            exit 2 ;;  # bad short option (error reported via getopts)
    esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

## Check required commands exist - print helptext if no input exists

# HT: Lionel
# https://stackoverflow.com/a/13864829/2518990

if [ -z ${input+x} ] && [ -z ${inputbed+x} ] && [ -z ${inputbgen+x} ]
then
    echo -e "\nERROR: Must have one of --input, --inputbed, or --inputbgen"
    echo "
All flags possible and required for the pipeline are listed below.

Note the '--' flags and the necessity for arguments to be attached to flags with '='

    --input
        - MANDATORY
        - Prefix of the input file
        - Hard-called imputed data is recommended to maximise coverage
        - Ensure that the same genome build is being used across cohorts (otherwise start and end below will be inconsistent across cohorts)
	- PLINK: Format should be PLINK binary (i.e. input.{bed,bim,fam})
	- bgen: Format should be bgen, index and .sample file (i.e. input.{bgen,bgi,sample})
    --inputbed
    --inputbim
    --inputfam
    --inputbgen
    --inputbgi
    --inputsample
        - OPTIONAL
	- As --input above, but separate files
    --chromosome
        - MANDATORY
        - Chromosome of the region to be included in the LD matrix
    --start
	- MANDATORY
        - Leftmost base position of the region to be included in the LD matrix (inclusive)
    --end
	- MANDATORY
        - Rightmost base position of the region to be included in the LD matrix (inclusive)
    --extract
	- OPTIONAL
        - List of SNPs to be included in the LD matrix, one SNP per line, no header.
    --keep
        - OPTIONAL
        - List of individuals to be used when calculating the LD matrix.
	- Should be a list of samples, one sample per line, no header. Samples should be identified by ID_1 from the .sample file (FID from the .fam file)
    --samplen
        - MANDATORY
	- N of samples to include in the LD matrix
	- Should be NCase + NControl for a binary phenotype (i.e. not NEff)
    --threads
        - OPTIONAL
        - Set number of threads for ldstore to use (defaults to 1)
    --output
	- MANDATORY
        - Prefix of output file names
	- Will overwrite any files with same names (see [Output](#output) below)!
    --inputtype
        - MANDATORY
        - Type of input file - must be 'plink', 'plinkbgen' or 'bgen'
	- plink
	    - Filtering operations are run in plink2
	    - Output is converted to bgen for generating LD matrix
	- plinkbgen
	    - Input is converted to bgen in plink2
	    - Filtering operations are run in qctool2
	    - Output is converted to bgen for generating LD matrix
	- bgen
	    - Filtering operations are run in qctool2
	    - Output is converted to bgen for generating LD matrix	
    --ldstorepath
        - MANDATORY
        - Full path to LDStore v2 binary
    --plinkpath
	- plink MANDATORY // plinkbgen MANDATORY // bgen NOT REQUIRED
        - Full path to PLINK2 program (not including program itself).
    --bgenixpath
	- MANDATORY
        - Full path to bgenix program (not including program itself).
    --qctoolpath
	- plink NOT REQUIRED // plinkbgen MANDATORY // bgen MANDATORY
        - Full path to qctool2 binary (not including program itself).
"
    exit
fi

if [ -z ${input+x} ] && [ -z ${inputbed+x} ]
then
    if [ -z ${inputbgi+x} ]
    then
	echo -e "\nERROR: --inputbgen must have --inputbgi\n"
	exit
    fi
    if [ -z ${inputsample+x} ]
    then
	echo -e "\nERROR: --inputbgen must have --inputsample\n"
	exit
    fi
fi

if [ -z ${input+x} ] && [ -z ${inputbgen+x} ]
then
    if [ -z ${inputbim+x} ]
    then
        echo -e "\nERROR: --inputbed must have --inputbim\n"
        exit
    fi
    if [ -z ${inputfam+x} ]
    then
        echo -e "\nERROR: --inputbed must have --inputfam\n"
        exit
    fi
fi

if [ -z ${chromosome+x} ]
then
    echo -e "\nERROR: Must have --chromosome\n"
    exit
fi

if [ -z ${start+x} ]
then
    echo -e "\nERROR: Must have --start\n"
    exit
fi

if [ -z ${end+x} ]
then
    echo -e "\nERROR: Must have --end\n"
    exit
fi

if [ -z ${samplen+x} ]
then
    echo -e "\nERROR: Must have --samplen\n"
    exit
fi

if [ -z ${threads+x} ]
then
    threads=1
fi

if [ -z ${output+x} ]
then
    echo -e "\nERROR: Must have --output\n"
    exit
fi

if [ -z ${inputtype+x} ]
then
    echo -e "\nERROR: Must have --inputtype\n"
    exit
fi

if [ -z ${ldstorepath+x} ]
then
    echo -e "\nERROR: Must have --ldstorepath\n"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${bgenixpath+x} ]
then
    echo -e "\nERROR: Must have at least one of --plinkpath or --bgenixpath\n"
    exit
fi

if [ -z ${bgenixpath+x} ]
then
    echo -e "\nERROR: Must have --bgenixpath\n"
    exit
fi

if [ -z ${bgenixpath+x} ] && [ -z ${qctoolpath+x} ]
then
    echo -e "\nERROR: --bgenixpath must be accompanied by --qctoolpath\n"
    exit
fi

if [ $inputtype != "plink" ] && [ $inputtype != "plinkbgen" ] && [ $inputtype != "bgen" ]
then  
    echo -e "\nERROR: --inputtype must be 'plink', 'plinkbgen' or 'bgen'\n"
    exit
fi	

#####################################################################################
#####################################################################################
################################ PREPARE INPUT BGEN #################################
#####################################################################################
#####################################################################################

## Input is PLINK

if [ $inputtype == "plink" ]
then

    echo -e "\nInput is PLINK\n"

    if [ -z ${inputbed+x} ]
    then
	inputbed=$input.bed
        inputbim=$input.bim
        inputfam=$input.fam
    fi
    
    if [ -z ${keep+x} ] && [ -z ${extract+x} ]
    then

	echo -e "\nConvert to bgen and filter to chromosome:start-end\n"
	
	$plinkpath/plink2 \
            --bed $inputbed \
            --bim $inputbim \
            --fam $inputfam \
            --export bgen-1.2 \
            --threads $threads \
            --out ${output}_chr${chromosome}_${start}_${end} \
	    --chr $chromosome \
	    --extract bed1 <(echo $chromosome $start $end) \
    	    --write-snplist

    elif [ -z ${keep+x} ]
    then

	echo -e "\nConvert to bgen and filter to extract list\n"
	
	$plinkpath/plink2 \
	    --bed $inputbed \
	    --bim $inputbim \
	    --fam $inputfam \
	    --export bgen-1.2 \
	    --threads $threads \
	    --out ${output}_chr${chromosome}_${start}_${end} \
	    --chr $chromosome \
	    --extract $extract \
	    --write-snplist
	
    elif [ -z ${extract+x} ]
    then

	echo -e "\nConvert to bgen, filter to chromosome:start-end, keep only keep individuals\n"
	
	$plinkpath/plink2 \
	    --bed $inputbed \
	    --bim $inputbim \
	    --fam $inputfam \
	    --export bgen-1.2 \
	    --threads $threads \
	    --out ${output}_chr${chromosome}_${start}_${end} \
	    --chr $chromosome \
	    --keep $keep \
	    --extract bed1 <(echo $chromosome $start $end) \
    	    --write-snplist

    else

	echo -e "\nConvert to bgen, filter to extract list, keep only keep individuals\n"
	
	$plinkpath/plink2 \
	    --bed $inputbed \
	    --bim $inputbim \
	    --fam $inputfam \
	    --export bgen-1.2 \
	    --threads $threads \
	    --out ${output}_chr${chromosome}_${start}_${end} \
	    --chr $chromosome \
	    --keep $keep \
	    --extract $extract \
	    --write-snplist
    fi

    ## Write Z files for LDStore

    cat <(echo "rsid chromosome position allele1 allele2") \
	<(LANG=C fgrep -wf ${output}_chr${chromosome}_${start}_${end}.snplist $inputbim | awk '{print $2, $1, $4, $5, $6}') \
	> ${output}_chr${chromosome}_${start}_${end}.z

    # Remove snplist

    rm ${output}_chr${chromosome}_${start}_${end}.snplist

else
    
    ## Input is PLINK

    if [ $inputtype == "plinkbgen" ]
    then
	
	echo -e "\nInput is PLINK, using BGen methods\n"

	if [ -z ${inputbed+x} ]
	then

	    inputbed=$input.bed
            inputbim=$input.bim
            inputfam=$input.fam
	fi

	echo -e "\nConvert to bgen and filter to chromosome:start-end\n"

	$plinkpath/plink2 \
            --bed $inputbed \
            --bim $inputbim \
            --fam $inputfam \
            --export bgen-1.2 \
            --threads $threads \
            --out $output \
	    --chr $chromosome \
	    --extract bed1 <(echo $chromosome $start $end)

	# Convert sample format to qctoolv2 version

	cat \
	    <(echo "ID missing sex PHENO1") \
	    <(echo "0 0 D B") \
	    <(awk 'NR > 2 {print $1"_"$2, $3, $4, $5}' $output.sample) \
	    > TEMP.sample

	mv TEMP.sample $output.sample

	inputbgen=$output.bgen
	inputbgi=$output.bgen.bgi
	inputsample=$output.sample

	echo -e "\nMake input bgi\n"

	$bgenixpath/bgenix -g $inputbgen -index

    fi

    ## Input is bgen

    if [ $inputtype == "bgen" ]
    then

	echo -e "\nInput is bgen\n"

	if [ -z ${inputbgen+x} ]
	then
	    inputbgen=$input.bgen
	    inputbgi=$input.bgen.bgi
	    inputsample=$input.sample
	fi
    fi
   
    ## Split data to segment for regions of interest and write Z files

    # Give chromosome leading 0 for segment extraction

    if [ $chromosome -lt 10 ]
    then
	rangechromosome=$(echo "0"$chromosome)
    else
	rangechromosome=$chromosome
    fi

    # Split to segment

    echo -e "\nSplitting to "$chromosome":"$start"-"$end

    $bgenixpath/bgenix \
	-g $inputbgen \
	-i $inputbgi \
	-incl-range ${rangechromosome}:${start}-${end} > ${output}_chr${chromosome}_${start}_${end}_TEMP.bgen

    if [ -z ${extract+x} ]
    then

        # Get SNPs in segment

	cat <(echo "SNPID rsid chromosome position A1 A2") \
	    <($bgenixpath/bgenix \
		  -g $inputbgen \
		  -i $inputbgi \
		  -incl-range ${rangechromosome}:${start}-${end} -list | \
		  awk '$2 != "bgenix:" && $2 != "rsid" {print $1, $2, $3, $4, $6, $7}') \
	    > ${output}_chr${chromosome}_${start}_${end}.incl.snps

    else

	echo -e "\nExtracting SNPs from" $extract

	# Filter segment for SNPs in extract list

	cat <(echo "SNPID rsid chromosome position A1 A2") \
	    <(LANG=C fgrep -wf $extract \
		  <($bgenixpath/bgenix \
			-g $inputbgen \
			-i $inputbgi \
			-incl-range ${rangechromosome}:${start}-${end} -list) | \
		  awk '$2 != "bgenix:" && $2 != "rsid" {print $1, $2, $3, $4, $6, $7}') \
	    > ${output}_chr${chromosome}_${start}_${end}.incl.snps

    fi

    awk -v chromosome=$chromosome '{print $1, $2, $3, $4, $5, $6, $1, $2, chromosome, $4, $5, $6}' ${output}_chr${chromosome}_${start}_${end}.incl.snps \
        > ${output}_chr${chromosome}_${start}_${end}.remap
    
    qctoolcommand=$(echo $qctoolpath/qctool \
			 -g ${output}_chr${chromosome}_${start}_${end}_TEMP.bgen \
			 -map-id-data ${output}_chr${chromosome}_${start}_${end}.remap \
			 -incl-variants ${output}_chr${chromosome}_${start}_${end}.incl.snps \
			 -compare-variants-by position,alleles \
			 -s $inputsample)

    if [ -z ${keep+x} ]
    then
	qctoolcommand=$(echo $qctoolcommand " -og " ${output}_chr${chromosome}_${start}_${end}.bgen)
	$qctoolcommand
    else
	qctoolcommand=$(echo $qctoolcommand " -incl-samples " $keep " -og " ${output}_chr${chromosome}_${start}_${end}.bgen)
	$qctoolcommand
    fi

    ## Clean up temporary bgen

    rm ${output}_chr${chromosome}_${start}_${end}_TEMP.bgen

    
    ## Write Z files

    awk '{print $2, $3, $4, $5, $6}' ${output}_chr${chromosome}_${start}_${end}.remap | \
	sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' -e 's/ '$rangechromosome' / '$chromosome' /g' \
	    > ${output}_chr${chromosome}_${start}_${end}.z

    ## Clean up extra files

    rm ${output}_chr${chromosome}_${start}_${end}.remap ${output}_chr${chromosome}_${start}_${end}.incl.snps

fi

#####################################################################################
#####################################################################################
########################### GENERATE LD SUMMARY MATRICES ############################
#####################################################################################
#####################################################################################

## Index bgen

$bgenixpath/bgenix \
    -g ${output}_chr${chromosome}_${start}_${end}.bgen \
    -index

## Write master files

masterroot=$(echo ${output}"_chr"${chromosome}"_"${start}"_"${end})

if [ -z ${keep+x} ]
then
    cat <(echo "z;bgen;bgi;bcor;ld;n_samples;sample") \
	<(echo -e "${masterroot}.z;${masterroot}.bgen;${masterroot}.bgen.bgi;${masterroot}.bcor;${masterroot}.ld;$samplen;$inputsample") >  $masterroot.master
else
    cat <(echo "z;bgen;bgi;bcor;ld;n_samples;sample;incl") \
	<(echo -e "${masterroot}.z;${masterroot}.bgen;${masterroot}.bgen.bgi;${masterroot}.bcor;${masterroot}.ld;$samplen;$inputsample;$keep") >  $masterroot.master
fi

## Write bcor

$ldstorepath/ldstore_v2.0_x86_64 \
    --in-files $masterroot.master \
    --write-bcor \
    --read-only-bgen \
    --compression low \
    --n-threads $threads

## Clean up

rm $masterroot.master ${masterroot}.z ${masterroot}.bgen ${masterroot}.bgen.bgi 

