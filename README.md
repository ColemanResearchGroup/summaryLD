# summaryLD
Code for generating summary LDStore files from PLINK binary and Oxford format bgen data

## Background

Multi-variant fine-mapping requires highly accurate estimates of linkage disequilibrium, best obtained from the data itself.
This poses a challenge in meta-analytical studies where some cohorts can only share summary statistics.
The software [LDStorev2](http://www.christianbenner.com/#) provides a mechanism whereby summary LD matrices can be generated and shared without needing individual-level data to be shared.
This repository provides code and instructions to generate summary LDStore2 files.

## Dependencies and Installation

This code requires [LDStore2](http://www.christianbenner.com/#) and [bgenix](https://enkre.net/cgi-bin/code/bgen/doc/trunk/doc/wiki/bgenix.md).

Support for additional input files can be requested - at present, only PLINK binaries and bgen1.2 input file types are supported.
When using PLINK binary input, the pipeline requires [PLINK2](https://www.cog-genomics.org/plink/2.0).
When using bgen1.2 input, the pipeline requires [qctool2](https://www.well.ox.ac.uk/~gav/qctool/).

This code was developed in a Linux environment (4.19.0-19-amd64) - it should run in other POSIX environments, but has not as yet been widely tested.

## Installation

### LDStore2 - Mandatory

```

wget http://www.christianbenner.com/ldstore_v2.0_x86_64.tgz
tar xzvf ldstore_v2.0_x86_64.tgz

```

### BGenix - Mandatory

Code below from [BGEN website](https://enkre.net/cgi-bin/code/bgen)

```

# get it
wget http://code.enkre.net/bgen/tarball/release/bgen.tgz
# make bgen folder
mkdir bgen
# extract the tar
tar xzvf bgen.tgz -C bgen --strip-components 1
# move to bgen
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

### PLINK2 - Optional

```

wget https://s3.amazonaws.com/plink2-assets/alpha2/plink2_linux_x86_64.zip
unzip plink2_linux_x86_64.zip

```

## Running the pipeline

To generate LDStore files, run:

```

# For PLINK input - Input.{bed,bim,fam}
# Limiting to SNPs - SNPs.txt
# Limiting to individuals - Indivs.txt
# Extracting LD for chromosome 1, positions 1-3000000
# 10000 individuals in Indivs.txt
# Running LDStore2 on 4 threads
# NOTE: all path variables should path to the program, but not include the program

bash \
GenerateLDStore.bash \
--input=Input \
--chromosome=1 \
--start=1 \
--end=3000001 \
--extract=SNPs.txt \
--keep=Indivs.txt \
--samplen=10000 \
--threads=2 \
--output=OutputName \
--inputtype=plinkmain \
--ldstorepath=path/to/ldstore \
--plinkpath=/path/to/plink \
--bgenixpath /path/to/bgenix

# For BGen1.2 input - Input.{bgen,bgi,sample}
# Other options as above

bash \
GenerateLDStore.bash \
--input=Input \
--chromosome=1 \
--start=1 \
--end=3000001 \
--extract=SNPs.txt \
--keep=Indivs.txt \
--samplen=10000 \
--threads=2 \
--output=OutputName \
--inputtype=bgen \
--ldstorepath=path/to/ldstore \
--bgenixpath /path/to/bgenix \
--qctoolpath /path/to/qctool

```

## Pipeline explained

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

## Output

    - ${input}_chr${chromosome}_${start}_${end}.bcor
        - Summary correlation matrix for the segment

