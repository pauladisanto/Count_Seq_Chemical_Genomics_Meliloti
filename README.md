# Count_Seq_Chemical_Genomics_Meliloti

Nextflow workflow for quantifying read counts from a *Sinorhizobium meliloti* mutant library

---

## Overview

This repository contains a Nextflow-based pipeline to analyse sequencing data from the *S. meliloti* mutant library described in Pobigaylo et al. (2006).

The workflow is designed to:

- Process sequencing reads from the tagged mutant library  
- Quantify read counts using Salmon  
- Focus exclusively on **H signatures**, ignoring K signatures  

---

## Usage

Run the workflow with:

```bash
nextflow run path/to/main.nf \
    -c path/to/nextflow.config \
    --input_dir /path/to/folder/fastq \
    --metadata_f /path/to/metadata_F.fasta \
    --metadata_r /path/to/metadata_R.fasta \
    --salmon_fasta /path/to/H_signatures_unique.fasta
```

The `nextflow.config` file contains workflow settings such as CPU allocation, trimming thresholds, Cutadapt parameters, and Salmon quantification options. Default values can be modified directly in the configuration file or overridden from the command line.

## Required Inputs

### `--input_dir`

Path to the working directory.

* Contains the input sequencing files (`FASTQ.gz`)
* Stores all intermediate files generated during the workflow
* Stores the final output files and reports

### `--metadata_f`

Path to the FASTA file containing the forward tag sequences used during pool demultiplexing.

A template file (`metadata_F.fasta`) is included in this repository.

### `--metadata_r`

Path to the FASTA file containing the reverse tag sequences used during condition demultiplexing.

A template file (`metadata_R.fasta`) is included in this repository.

### `--salmon_fasta`

Path to the FASTA file containing the unique H signatures used for quantification.

This file is used to build the Salmon index before quantification.

Only H signatures are analysed in this workflow.

### `-c nextflow.config`

Path to the Nextflow configuration file.

This file defines configurable workflow parameters, including:

* Number of CPU threads (`ncpus`)
* Trim Galore quality threshold
* Cutadapt overlap and mismatch settings
* Minimum read length after demultiplexing
* Salmon quantification settings
* Common sequence trimming parameters

Default parameter values were tested on an AMD Ryzen 7 PRO 7840U laptop (8 cores, 16 threads, 32 GB RAM) and provide a good balance between runtime and resource usage on typical desktop and laptop systems.


BASH scripts were developed using a template script written by Sunniva Sigurdardóttir (GitHub: sunnivass)

For any questions, you can contact me at: gdisantomeztler@gmail.com

### Environment

Option 1 — Conda environment

Create and activate the environment:
```bash
conda env create -f environment.yml
conda activate meliloti_nf
```
Verify installation:
```bash
trim_galore --version
fastqc --version
cutadapt --version
multiqc --version
bbmap.sh --version
salmon --version
```

Option 2 — Singularity container (recommended)

Build the container from the definition file:
The files are located in the folder environments
```bash
sudo singularity build meliloti_nf.sif meliloti_nf.def

Run tools inside the container:

singularity exec meliloti_nf.sif salmon --version
singularity exec meliloti_nf.sif fastqc --version
```
Open an interactive shell:
```bash
singularity shell meliloti_nf.sif
```

Notes
The .sif file is not included in this repository because it is a large binary file.
Users can build it locally using the provided meliloti_nf.def.
The container ensures consistent results across systems, especially on HPC clusters.

Requirements
Conda (for Option 1), or
Singularity / Apptainer (for Option 2)



## Configurable Parameters

The workflow uses a `nextflow.config` file to centralize commonly modified parameters. This allows users to adjust computational resources and analysis settings without modifying the workflow source code.

### Computational Resources

| Parameter | Default | Description                                                                       |
| --------- | ------- | --------------------------------------------------------------------------------- |
| `ncpus`   | `4`     | Number of CPU threads used by FastQC, Trim Galore, BBMerge, Cutadapt, and Salmon. |

Recommended values:

| Hardware                  | Suggested `ncpus`                |
| ------------------------- | -------------------------------- |
| Older laptop (2–4 cores)  | 2                                |
| Modern laptop (4–8 cores) | 4                                |
| High-end workstation      | 6–8                              |
| HPC cluster               | According to allocated resources |

### Quality Trimming

| Parameter      | Default | Description                                         |
| -------------- | ------- | --------------------------------------------------- |
| `trim_quality` | `30`    | Phred quality threshold used by Trim Galore (`-q`). |

### Pool Demultiplexing (Forward Tags)

| Parameter             | Default | Description                                        |
| --------------------- | ------- | -------------------------------------------------- |
| `cutadapt_error_rate` | `0`     | Allowed mismatch rate during pool demultiplexing.  |
| `cutadapt_overlap`    | `26`    | Minimum overlap required between barcode and read. |

### Condition Demultiplexing (Reverse Tags)

| Parameter              | Default | Description                                            |
| ---------------------- | ------- | ------------------------------------------------------ |
| `condition_error_rate` | `0`     | Allowed mismatch rate during condition demultiplexing. |
| `condition_overlap`    | `26`    | Minimum overlap required between barcode and read.     |
| `condition_min_length` | `20`    | Minimum read length retained after demultiplexing.     |

### Salmon Quantification

| Parameter                   | Default | Description                                              |
| --------------------------- | ------- | -------------------------------------------------------- |
| `salmon_libtype`            | `"A"`   | Automatic library type detection.                        |
| `salmon_min_assigned_frags` | `1`     | Minimum number of assigned fragments required by Salmon. |

### Common Sequence Removal

| Parameter                | Default                          | Description                                           |
| ------------------------ | -------------------------------- | ----------------------------------------------------- |
| `common_5prime_sequence` | `TACTAGCTCTACGACGGTCCACCTAAGCTT` | 5' common sequence removed prior to quantification.   |
| `common_3prime_sequence` | `AAGCTT`                         | Sequence used to trim reads after the cloning site.   |
| `common_error_rate`      | `0`                              | Allowed mismatch rate during common sequence removal. |

