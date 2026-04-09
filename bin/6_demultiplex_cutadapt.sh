#!/usr/bin/env bash

set -euo pipefail

ncpus=7

while getopts "p:" flag; do
    case "${flag}" in
        p) pdir="${OPTARG}" ;;
        *)
            echo "Usage: $0 -p <project_directory>"
            exit 1
            ;;
    esac
done

if [ -z "${pdir:-}" ]; then
    echo "ERROR: Please provide -p <project_directory>"
    exit 1
fi

samp=$(basename "${pdir}")
echo ">>> Processing batch ${samp} <<<"

mkdir -p "${pdir}/demultiplexed_POOL"

meta_fasta="${pdir}/metadata_F.fasta"

if [ ! -f "${meta_fasta}" ]; then
    echo "ERROR: Metadata FASTA not found: ${meta_fasta}"
    exit 1
fi

shopt -s nullglob
merged_files=( "${pdir}/merged"/*_trimmed_merged.fastq.gz )

if [ ${#merged_files[@]} -eq 0 ]; then
    echo "ERROR: No merged files found in ${pdir}/merged"
    exit 1
fi

echo -e "\n\n >>> DEMULTIPLEX BATCH <<< \n\n"

for merged in "${merged_files[@]}"; do
    name_seq=$(basename "${merged}" "_trimmed_merged.fastq.gz")

    echo "Processing merged file: ${name_seq}"

    if ! gzip -t "${merged}" 2>/dev/null; then
        echo "ERROR: Input merged file is not a valid gzip file: ${merged}"
        exit 1
    fi

    rm -f "${pdir}"/demultiplexed_POOL/*_"${name_seq}"_trimmed_merged_demux.fastq.gz

    cutadapt \
        -g "file:${meta_fasta}" \
        -e 0 \
        -O 26 \
        --rename='{id} {comment} sample={adapter_name}' \
        --rc \
        -j "${ncpus}" \
        -o "${pdir}/demultiplexed_POOL/{name}_${name_seq}_trimmed_merged_demux.fastq.gz" \
        "${merged}"

    outputs=( "${pdir}"/demultiplexed_POOL/*_"${name_seq}"_trimmed_merged_demux.fastq.gz )

    if [ ${#outputs[@]} -eq 0 ]; then
        echo "WARNING: No demultiplexed output files produced for ${name_seq}"
        continue
    fi

    valid_outputs=0

    for out in "${outputs[@]}"; do
        if [ ! -s "${out}" ]; then
            echo "WARNING: Output file is empty: ${out}. Removing."
            rm -f "${out}"
            continue
        fi

        if ! gzip -t "${out}" 2>/dev/null; then
            echo "ERROR: Invalid gzip output produced: ${out}"
            exit 1
        fi

        valid_outputs=$((valid_outputs + 1))
    done

    if [ "${valid_outputs}" -eq 0 ]; then
        echo "ERROR: All demultiplexed outputs were empty or invalid for ${name_seq}"
        exit 1
    fi

    echo "Validated output files for ${name_seq}:"
    printf '  %s\n' "${pdir}"/demultiplexed_POOL/*_"${name_seq}"_trimmed_merged_demux.fastq.gz
done

echo -e "\n\n\n >>> FINISHED DEMULTIPLEX <<< \n\n\n"