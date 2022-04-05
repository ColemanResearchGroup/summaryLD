### Script: Generate LDStore LD Matrix files
### Date: 2022-03-25
### Authors: JRIColeman
### Version: 0.1.2022.04.05

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
    bgenpath )    needs_arg; bgenpath="$OPTARG" ;;
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
	 - PLINK: Should be in PLINK --keep format if included.
	 - bgen: Should be a list of samples, one sample per line, no header. Samples should be identified by ID_1 from the .sample file.
    --samplen
        - MANDATORY
	 - N of samples to include in the LD matrix
	 - Should be NCase + NControl for a binary phenotype (i.e. not NEff)
    --output
	 - MANDATORY
        - Prefix of output file names
	 - Will overwrite any files with same names (see [Output](#output) below)!
    --inputtype
        - MANDATORY
        - Type of input file - must be 'plink' or 'bgen'
    --ldstorepath
        - MANDATORY
        - Full path to LDStore v2 binary
    --plinkpath
	 - PLINK MANDATORY
        - Full path to PLINK1.9 binary. Can be left out if type=bgen
    --bgenpath
    --qctoolpath
	 - bgen MANDATORY
        - Full paths to bgen tools folder and to qctool2 binary. Can be left out if type=plink
"
    exit
fi

if [ -z ${input+x} ] && [ -z ${inputbed+x} ]
then
    if [ -z ${inputbgi+x} ]
    then
	echo -e "\nERROR: --inputbgen must have --inputbgi"
	exit
    fi
    if [ -z ${inputsample+x} ]
    then
	echo -e "\nERROR: --inputbgen must have --inputsample"
	exit
    fi
fi

if [ -z ${input+x} ] && [ -z ${inputbgen+x} ]
then
    if [ -z ${inputbim+x} ]
    then
        echo -e "\nERROR: --inputbed must have --inputbim"
        exit
    fi
    if [ -z ${inputfam+x} ]
    then
        echo -e "\nERROR: --inputbed must have --inputfam"
        exit
    fi
fi

if [ -z ${chromosome+x} ]
then
    echo -e "\nERROR: Must have --chromosome"
    exit
fi

if [ -z ${start+x} ]
then
    echo -e "\nERROR: Must have --start"
    exit
fi

if [ -z ${end+x} ]
then
    echo -e "\nERROR: Must have --end"
    exit
fi

if [ -z ${samplen+x} ]
then
    echo -e "\nERROR: Must have --samplen"
    exit
fi

if [ -z ${threads+x} ]
then
    threads=1
fi

if [ -z ${output+x} ]
then
    echo -e "\nERROR: Must have --output"
    exit
fi

if [ -z ${inputtype+x} ]
then
    echo -e "\nERROR: Must have --inputtype"
    exit
fi

if [ -z ${ldstorepath+x} ]
then
    echo -e "\nERROR: Must have --ldstorepath"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${bgenpath+x} ]
then
    echo -e "\nERROR: Must have at least one of --plinkpath or --bgenpath"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${qctoolpath+x} ]
then
    echo -e "\nERROR: --bgenpath must be accompanied by --qctoolpath"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${keep+x} ]
then
    echo -e "\nERROR: --bgenpath must be accompanied by a .sample file passed to --keep"
    exit
fi

## Input is PLINK

if [ $inputtype -eq "plink" ]
then

    echo -e "\nInput is PLINK"


fi

## Input is bgen

if [ $inputtype -eq "bgen" ]
then

    echo -e "\nInput is bgen"

    if [ -z ${inputbgen+x} ]
    then
	inputbgen=$input.bgen
	inputbgi=$input.bgi
	inputsample=$input.sample
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

    echo -e "\nSplitting to " $chromosome":"$start"-"$end

    $bgenpath/bin/bgenix \
	-g $inputbgen \
	-i $inputbgi \
	-incl-range ${rangechromosome}:${start}-${end} > ${input}_chr${chr}_${start}_${end}_TEMP.bgen

    if [ -z ${extract+x} ]
    then

        # Get SNPs in segment

	cat <(echo "SNPID rsid rangechromosome position A1 A2 SNPID rsid chromosome position A1 A2") \
	    <($bgenpath/bin/bgenix \
		  -g $inputbgen \
		  -i $inputbgi \
		  -incl-range ${rangechromosome}:${start}-${end} -list | \
		  awk -v chromosome=$chromosome '{print $1, $2, $3, $4, $6, $7, $1, $2, chromosome, $4, $6, $7}') \
	    > ${input}_chr${chr}_${start}_${end}.incl.list

    else

	echo -e "\nExtracting SNPs from " $extract

	# Filter segment for SNPs in extract list

	cat <(echo "SNPID rsid rangechromosome position A1 A2 SNPID rsid chromosome position A1 A2") \
	    <(LANG=C fgrep -wf $extract \
		  <($bgenpath/bin/bgenix \
			-g $inputbgen \
			-i $inputbgi \
			-incl-range ${rangechromosome}:${start}-${end} -list) | \
		  awk -v chromosome=$chromosome '{print $1, $2, $3, $4, $6, $7, $1, $2, chromosome, $4, $6, $7}') \
	    > ${input}_chr${chr}_${start}_${end}.incl.list

    fi

    qctoolcommand=$qctoolpath/qctool \
		 -g ${input}_chr${chr}_${start}_${end}_TEMP.bgen \
		 -map-id-data ${input}_chr${chr}_${start}_${end}.incl.list \
		 -incl-variants <(awk '{print $1, $2, $3, $4, $5, $6}' ${input}_chr${chr}_${start}_${end}.incl.list) \
		 -s $inputsample

    if [ -z ${keep+x} ]
    then
	qctoolcommand=$(echo $qctoolcommand " -og " ${input}_chr${chr}_${start}_${end}.bgen)
	$qctoolcommand
    else
	qctoolcommand=$(echo $qctoolcommand " -incl-samples " $keep " -og " ${input}_chr${chr}_${start}_${end}.bgen)
	$qctoolcommand
    fi

    ## Clean up temporary bgen

    rm ${input}_chr${chr}_${start}_${end}_TEMP.bgen

    ## Index bgen

    $bgenpath/bin/bgenix \
	-g ${input}_chr${chr}_${start}_${end}.bgen \
	-index

    ## Write Z files

    awk '{print $2, $3, $4, $5, $6}' ${input}_chr${chr}_${start}_${end}.incl.list | \
	sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' -e 's/ '$rangechromosome' / '$chromosome' /g' \
	    > ${input}_chr${chr}_${start}_${end}.z

    ## Write master files

    masterroot=$(echo ${input}"_chr"${chr}"_"${start}"_"${end})

    if [ -z ${master+x} ]
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

    rm $masterroot.master ${masterroot}.z ${masterroot}.bgen ${masterroot}.bgen.bgi ${masterroot}.incl.list

fi
