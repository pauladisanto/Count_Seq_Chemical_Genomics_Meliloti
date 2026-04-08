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

mkdir -p "${pdir}/fastqc" "${pdir}/trimmed"

echo -e "\n\n\n >>> FastQC reports <<< \n\n\n"

fastqc -t 8 "${pdir}"/*_1.fastq.gz "${pdir}"/*_2.fastq.gz -o "${pdir}/fastqc"

echo -e "\n\n\n >>> TRIMMING of bad quality bases <<< \n\n\n"

shopt -s nullglob
r1_files=( "${pdir}"/*_1.fastq.gz )

if [ ${#r1_files[@]} -eq 0 ]; then
    echo "ERROR: No read 1 files found in ${pdir}"
    exit 1
fi

for r1 in "${r1_files[@]}"; do
    r2="${r1%_1.fastq.gz}_2.fastq.gz"

    if [ ! -f "${r2}" ]; then
        echo "ERROR: Matching read 2 file not found for ${r1}"
        echo "Expected: ${r2}"
        exit 1
    fi

    base=$(basename "${r1}" _1.fastq.gz)
    echo -e "\n\n >> Trimming sample ${base} << \n\n"

    trim_galore \
        -q 30 \
        -j "${ncpus}" \
        --fastqc \
        --trim-n \
        --paired \
        "${r1}" "${r2}" \
        --fastqc_args "--outdir ${pdir}/fastqc" \
        -o "${pdir}/trimmed"
done

echo -e "\n >>> FINISHED TRIMMING <<< \n"