#!/usr/bin/env bash

set -euo pipefail

ncpus=7

while getopts "p:" flag; do
    case "${flag}" in
        p) pdir="${OPTARG}" ;;
    esac
done

if [ -z "${pdir:-}" ]; then
    echo "ERROR: Please provide -p <project_directory>"
    exit 1
fi

samp=$(basename "${pdir}")
echo ">>> Processing batch ${samp} <<<"

mkdir -p "${pdir}/merged"

shopt -s nullglob
r1_files=( "${pdir}/trimmed"/*_1_val_1.fq.gz )

echo -e "\n\n >>> MERGE READS WITH BBMERGE <<< \n\n"
echo "Looking for files in: ${pdir}/trimmed"
echo "Pattern: *_1_val_1.fq.gz"
echo "Number of matching R1 files: ${#r1_files[@]}"

if [ ${#r1_files[@]} -eq 0 ]; then
    echo "ERROR: No files found matching ${pdir}/trimmed/*_1_val_1.fq.gz"
    exit 1
fi

for r1 in "${r1_files[@]}"; do
    r2="${r1%_1_val_1.fq.gz}_2_val_2.fq.gz"

    if [ ! -f "${r2}" ]; then
        echo "ERROR: Matching read 2 file not found for ${r1}"
        echo "Expected: ${r2}"
        exit 1
    fi

    base=$(basename "${r1}" _1_val_1.fq.gz)

    echo -e "\n\n >> Merging sample ${base} << \n\n"
    echo "  R1: ${r1}"
    echo "  R2: ${r2}"

    bbmerge.sh \
        in1="${r1}" \
        in2="${r2}" \
        out="${pdir}/merged/${base}_trimmed_merged.fastq.gz" \
        outu1="${pdir}/merged/${base}_trimmed_unmerged_1.fastq.gz" \
        outu2="${pdir}/merged/${base}_trimmed_unmerged_2.fastq.gz" \
        threads="${ncpus}"
done

echo -e "\n >>> FINISHED MERGING <<< \n"
