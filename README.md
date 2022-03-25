# summaryLD
Code for generating summary LDStore files from PLINK binary and Oxford format bgen data

## Background

Multi-variant fine-mapping requires highly accurate estimates of linkage disequilibrium, best obtained from the data itself.
This poses a challenge in meta-analytical studies where some cohorts can only share summary statistics.
The software [LDStorev2](http://www.christianbenner.com/#) provides a mechanism whereby summary LD matrices can be generated and shared without needing individual-level data to be shared.
This repository provides code and instructions to generate summary LDStore2 files.

## Dependencies and Installation

This code requires [LDStore2](http://www.christianbenner.com/#).
Depending on the nature of the input files, it may also require [PLINK1.9](https://www.cog-genomics.org/plink/) or the [BGEN tools suite](https://enkre.net/cgi-bin/code/bgen) (including [qctool2](https://www.well.ox.ac.uk/~gav/qctool/)).
Support for additional input files can be requested.

This code was developed in a Linux environment (4.19.0-19-amd64) - it should run in other POSIX environments, but has not as yet been widely tested.

## Installation

### LDStore2 - Mandatory

```

wget http://www.christianbenner.com/ldstore_v2.0_x86_64.tgz
tar xzvf ldstore_v2.0_x86_64.tgz

```

### PLINK1.9 - Optional

```

wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20220305.zip
unzip plink_linux_x86_64_20220305.zip

```

### BGEN tools - Optional

Code below from [BGEN website](https://enkre.net/cgi-bin/code/bgen)

```

# get it
wget http://code.enkre.net/bgen/tarball/release/bgen.tgz
cd bgen
# compile it
./waf configure
./waf
# test it
./build/test/unit/test_bgen
./build/apps/bgenix -g example/example.16bits.bgen -list

```

### qctool2 - Optional

```

wget https://www.well.ox.ac.uk/~gav/resources/qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz
tar xvfz qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz

```


## Running the pipeline

To generate LDStore files, run:

```

# For PLINK input - Input.{bed,bim,fam}
# Limiting to SNPs - SNPs.txt
# Limiting to individuals - Indivs.txt
# Extracting LD for chromosome 1, positions 1-3000000

bash \
GenerateLDStore.bash \
--input=Input \
--chromosome=1 \
--start=1 \
--end=3000001 \
--extract=SNPs.txt \
--keep=Indivs.txt \
--output=OutputName \
--inputtype=plink \
--ldstorepath=path/to/ldstore_v2.0_x86_64 \
--plinkpath=/path/to/plink

# For BGen input - Input.{bgen,bgi,sample}
# Other options as above

bash \
GenerateLDStore.bash \
--input=Input \
--chromosome=1 \
--start=1 \
--end=3000001 \
--extract=SNPs.txt \
--keep=Indivs.txt \
--output=OutputName \
--inputtype=bgen \
--ldstorepath=path/to/ldstore_v2.0_x86_64 \
--bgenpath /path/to/bgen_tools \
--qctoolpath /path/to/qctool

```

## Pipeline explained

All flags possible and required for the pipeline are listed below.
Note the "--" flags and the necessity for arguments to be attached to flags with "="

    --input
        - Prefix of the input file
        - Hard-called imputed data is recommended to maximise coverage
        - Ensure that the same genome build is being used across cohorts (otherwise start and end below will be inconsistent across cohorts)
    --chromosome
        - Chromosome of the region to be included in the LD matrix
    --start
        - Leftmost base position of the region to be included in the LD matrix (inclusive)
    --end
        - Rightmost base position of the region to be included in the LD matrix (inclusive)
    --extract
        - List of SNPs to be included in the LD matrix, one SNP per line, no header. Can be left out if no SNP filter is required
    --keep
        - List of individuals to be used when calculating the LD matrix, one set of individual IDs per line (as FID IID, space-delimited), no header. Can be left out if no individual filter is required
    --output
        - Prefix of output file names
    --inputtype
       - Type of input file - must be "plink" or "bgen"
    --ldstorepath
       - Full path to LDStore v2 binary
    --plinkpath
      - Full path to PLINK1.9 binary. Can be left out if type=bgen 
    --bgenpath
    --qctoolpath
      - Full paths to bgen tools folder and to qctool2 binary. Can be left out if type=plink

## Output
