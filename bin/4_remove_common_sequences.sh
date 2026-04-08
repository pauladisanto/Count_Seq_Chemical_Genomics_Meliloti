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

echo -e "\n\n >>> REMOVE COMMON SEQUENCES FROM TRIMMED READS <<< \n\n"

shopt -s nullglob

files=( "${pdir}/trimmed"/*_2_val_2.fq.gz )

echo "Looking for files in: ${pdir}/trimmed"
echo "Pattern: *_2_val_2.fq.gz"
echo "Number of matching files: ${#files[@]}"

if [ ${#files[@]} -eq 0 ]; then
    echo "ERROR: No files found matching ${pdir}/trimmed/*_2_val_2.fq.gz"
    exit 1
fi

mkdir -p "${pdir}/sequence_cutted"

for fn in "${files[@]}"; do
    name=$(basename "${fn}")
    echo -e "\n\n >> Processing sample ${name} << \n\n"

    cutadapt \
        -g TACTAGCTCTACGACGGTCCACCTAAGCTT \
        -e 0 \
        -j "${ncpus}" \
        -o "${pdir}/sequence_cutted/${name%.fq.gz}_adapter-trimmed.fastq.gz" \
        "${fn}"
done

echo -e "\n\n\n >>> FINISHED ADAPTER REMOVAL <<< \n\n\n"