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

##  Usage

Run the workflow with:

```bash
  nextflow run path/to/Nextflow_pipeline/main.nf \
  --input_dir /path/to/Test_complete_sequences \
  --metadata_f /path/to/Nextflow_pipeline/metadata_F.fasta \
  --metadata_r path/to/Nextflow_pipeline/metadata_R.fasta \
  --salmon_fasta path/to/H_signatures_unique.fasta 

```
##  Required Inputs

### `--input_dir`

Path to your working directory.

- This directory contains your input sequencing files  
- It will also be used to store all intermediate and final outputs  
- You can choose any location depending on your system setup 

### `--metadata_csv`

Path to the metadata file describing tag primers used in the experiment.

A template CSV file is included in this repository
Required for correct sample identification and processing

### `--salmon_fasta`

Path to the FASTA file containing the unique H signatures.

Used to build the Salmon index
Only H signatures are analysed in this workflow


BASH scripts were developed using a template script written by Sunniva Sigurdardóttir (GitHub: sunnivass)

For any questions, you can contact me at: gdisantomeztler@gmail.com