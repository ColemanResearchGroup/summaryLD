### Script: Generate LDStore LD Matrix files
### Date: 2022-03-25
### Authors: JRIColeman
### Version: 0.1.2022.03.25

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
    chromosome )    needs_arg; chromosome="$OPTARG" ;;
    start )    needs_arg; start="$OPTARG" ;;
    end )    needs_arg; end="$OPTARG" ;;
    extract )    needs_arg; extract="$OPTARG" ;;
    keep )    needs_arg; keep="$OPTARG" ;;
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

## Check required commands exist

# HT: Lionel
# https://stackoverflow.com/a/13864829/2518990

if [ -z ${input+x} ]
then
    echo "ERROR: Must have --input"
    exit
fi

if [ -z ${chromosome+x} ]
then
    echo "ERROR: Must have --chromosome"
    exit
fi

if [ -z ${start+x} ]
then
    echo "ERROR: Must have --start"
    exit
fi

if [ -z ${end+x} ]
then
    echo "ERROR: Must have --end"
    exit
fi

if [ -z ${output+x} ]
then
    echo "ERROR: Must have --output"
    exit
fi

if [ -z ${inputtype+x} ]
then
    echo "ERROR: Must have --inputtype"
    exit
fi

if [ -z ${ldstorepath+x} ]
then
    echo "ERROR: Must have --ldstorepath"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${bgenpath+x} ]
then
    echo "ERROR: Must have at least one of --plinkpath or --bgenpath"
    exit
fi

if [ -z ${plinkpath+x} ] && [ -z ${qctoolpath+x} ]
then
    echo "ERROR: --bgenpath must be accompanied by --qctoolpath"
    exit
fi

echo "All working"
exit



### Split to segment for regions of interest and write Z files

module add utilities/use.dev
module add apps/qctool/2.0.8

bunzip2 /scratch/groups/ukbiobank/usr/KCL_Data_Analyses/MDD_BIP/MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT.bz2

for chr in 1 5 14 18
do
    declare -i start
    declare -i end
    if [ $chr -eq 1 ]
    then
        for start in 71000001 72000001 73000001
	do
            end=$start+3000000

            LANG=C fgrep -wf daner_MDD29_noPharma_UKBB_SNPs.txt /scratch/groups/ukbiobank/usr/KCL_Data_Analyses/MDD_BIP/MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT | \
	    awk -v chr=$chr -v start=$start -v end=$end '$1 == chr && $3 >= start && $3 <= end {print $2}' \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps

            wc -l MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps
	    sort MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps | uniq | wc -l

            cat <(echo "SNPID rsid chromosome position A1 A2") \
            <(LANG=C fgrep -wf MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps \
            <(/scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
            -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range 0${chr}:${start}-${end} -list) | \
	    awk '{print $1, $2, $3, $4, $6, $7}') > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list

	    awk -v chr=$chr '{print $1, $2, $3, $4, $5, $6, $1, $2, chr, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap

            /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
      	    -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range 0${chr}:${start}-${end} > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            qctool -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen -map-id-data MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap \
	    -incl-variants MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    -s wukb16577_imp_chr1_v3_s487283.sample -incl-samples ukb_WG_v3_MAF1_INFO4.incl -og ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen

            rm ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            ## Index
	    /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen \
            -index

            ## Write Z files
	    awk '{print $2, $3, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list | \
	    sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' -e 's/ 01 / 1 /g' \
	    > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.z
        done
    fi
    if [ $chr -eq 5 ]
    then
        for start in 101000001 102000001 103000001 
	do
            end=$start+3000000

            LANG=C fgrep -wf daner_MDD29_noPharma_UKBB_SNPs.txt /scratch/groups/ukbiobank/usr/KCL_Data_Analyses/MDD_BIP/MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT | \
	    awk -v chr=$chr -v start=$start -v end=$end '$1 == chr && $3 >= start && $3 <= end {print $2}' \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps

            wc -l MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps
	    sort MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps | uniq | wc -l

            cat <(echo "SNPID rsid chromosome position A1 A2") \
            <(LANG=C fgrep -wf MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps \
            <(/scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
            -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range 0${chr}:${start}-${end} -list) | \
	    awk '{print $1, $2, $3, $4, $6, $7}') > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list

	    awk -v chr=$chr '{print $1, $2, $3, $4, $5, $6, $1, $2, chr, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap

            /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
      	    -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range 0${chr}:${start}-${end} > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            qctool -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen -map-id-data MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap \
	    -incl-variants MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    -s wukb16577_imp_chr1_v3_s487283.sample -incl-samples ukb_WG_v3_MAF1_INFO4.incl -og ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen

            rm ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            ## Index
	    /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen \
            -index

            ## Write Z files
	    awk '{print $2, $3, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list  | \
	    sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' -e 's/ 05 / 5 /g' \
	    > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.z
        done
    fi
    if [ $chr -eq 14 ]
    then
        for start in 40000001 41000001 42000001
	do
            end=$start+3000000

            LANG=C fgrep -wf daner_MDD29_noPharma_UKBB_SNPs.txt /scratch/groups/ukbiobank/usr/KCL_Data_Analyses/MDD_BIP/MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT | \
	    awk -v chr=$chr -v start=$start -v end=$end '$1 == chr && $3 >= start && $3 <= end {print $2}' \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps

            wc -l MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps
	    sort MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps | uniq | wc -l

            cat <(echo "SNPID rsid chromosome position A1 A2") \
            <(LANG=C fgrep -wf MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps \
            <(/scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
            -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range ${chr}:${start}-${end} -list) | \
	    awk '{print $1, $2, $3, $4, $6, $7}') > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list

	    awk -v chr=$chr '{print $1, $2, $3, $4, $5, $6, $1, $2, chr, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap

            /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
      	    -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range ${chr}:${start}-${end} > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            qctool -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen -map-id-data MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap \
	    -incl-variants MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    -s wukb16577_imp_chr1_v3_s487283.sample -incl-samples ukb_WG_v3_MAF1_INFO4.incl -og ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen

            rm ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            ## Index
	    /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen \
            -index

            ## Write Z files
	    awk '{print $2, $3, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list  | \
	    sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' \
	    > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.z
        done
    fi
    if [ $chr -eq 18 ]
    then
        for start in 29000001 30000001 31000001
	do
            end=$start+3000000

            LANG=C fgrep -wf daner_MDD29_noPharma_UKBB_SNPs.txt /scratch/groups/ukbiobank/usr/KCL_Data_Analyses/MDD_BIP/MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT | \
	    awk -v chr=$chr -v start=$start -v end=$end '$1 == chr && $3 >= start && $3 <= end {print $2}' \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps

            wc -l MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps
	    sort MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps | uniq | wc -l

            cat <(echo "SNPID rsid chromosome position A1 A2") \
            <(LANG=C fgrep -wf MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.snps \
            <(/scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
            -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range ${chr}:${start}-${end} -list) | \
	    awk '{print $1, $2, $3, $4, $6, $7}') > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list

	    awk -v chr=$chr '{print $1, $2, $3, $4, $5, $6, $1, $2, chr, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    > MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap

            /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen \
      	    -i ukb_imp_chr${chr}_v3_MAF1_INFO4.bgen.bgi \
            -incl-range ${chr}:${start}-${end} > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            qctool -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen -map-id-data MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.remap \
	    -incl-variants MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list \
	    -s wukb16577_imp_chr1_v3_s487283.sample -incl-samples ukb_WG_v3_MAF1_INFO4.incl -og ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen

            rm ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4_TEMP.bgen

            ## Index
	    /scratch/groups/ukbiobank/Edinburgh_Data/Software/bgen_tools/bin/bgenix \
            -g ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.bgen \
            -index

            ## Write Z files
	    awk '{print $2, $3, $4, $5, $6}' MHQ_Depression_WG_MAF1_INFO4_HRC_Only_Filtered_Dups_FOR_METACARPA_INFO6_A5_NTOT_chr${chr}_${start}_${end}.incl.list  | \
	    sed -e 's/A1/allele1/g' -e 's/A2/allele2/g' \	    
	    > ukb_imp_chr${chr}_${start}_${end}_v3_MAF1_INFO4.z
        done
    fi
done

## Write master files

for fileroot in ukb_imp_chr14_40000001_43000001_v3_MAF1_INFO4 \
ukb_imp_chr14_41000001_44000001_v3_MAF1_INFO4 \
ukb_imp_chr14_42000001_45000001_v3_MAF1_INFO4 \
ukb_imp_chr1_71000001_74000001_v3_MAF1_INFO4 \
ukb_imp_chr1_72000001_75000001_v3_MAF1_INFO4 \
ukb_imp_chr1_73000001_76000001_v3_MAF1_INFO4 \
ukb_imp_chr18_29000001_32000001_v3_MAF1_INFO4 \
ukb_imp_chr18_30000001_33000001_v3_MAF1_INFO4 \
ukb_imp_chr18_31000001_34000001_v3_MAF1_INFO4 \
ukb_imp_chr5_101000001_104000001_v3_MAF1_INFO4 \
ukb_imp_chr5_102000001_105000001_v3_MAF1_INFO4 \
ukb_imp_chr5_103000001_106000001_v3_MAF1_INFO4
do
    cat <(echo "z;bgen;bgi;bcor;ld;n_samples;sample;incl") <(echo -e "${fileroot}.z;${fileroot}.bgen;${fileroot}.bgen.bgi;${fileroot}.bcor;${fileroot}.ld;92945;wukb16577_imp_chr1_v3_s487283.sample;ukb_WG_v3_MAF1_INFO4.incl") >  ${fileroot}.master
done


## Write bcor

for file in *.master;
do
    /scratch/users/k1204688/Tools/PolyFun/ldstore_v2.0_x86_64/ldstore_v2.0_x86_64 \
    --in-files $file \
    --write-bcor \
    --read-only-bgen \
    --compression low \
    --n-threads 15
done

```