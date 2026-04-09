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

mkdir -p "${pdir}/demultiplexed_CONDITION"

meta_fasta="${pdir}/metadata_R.fasta"

if [ ! -f "${meta_fasta}" ]; then
    echo "ERROR: Reverse metadata FASTA not found: ${meta_fasta}"
    exit 1
fi

echo -e "\n\n >>> DEMULTIPLEX CONDITION BATCH <<< \n\n"

shopt -s nullglob
files=( "${pdir}"/demultiplexed_POOL/*_trimmed_merged_demux.fastq.gz )

echo "Looking for files in: ${pdir}/demultiplexed_POOL"
echo "Pattern: *_trimmed_merged_demux.fastq.gz"
echo "Number of matching files: ${#files[@]}"

if [ ${#files[@]} -eq 0 ]; then
    echo "ERROR: No files found matching ${pdir}/demultiplexed_POOL/*_trimmed_merged_demux.fastq.gz"
    exit 1
fi

for f in "${files[@]}"; do
    name_seq=$(basename "${f}")
    echo "Processing ${name_seq} ..."

    rm -f "${pdir}"/demultiplexed_CONDITION/*_"${name_seq%.fastq.gz}"_demux_a.fastq.gz

    if ! gzip -t "${f}" 2>/dev/null; then
        echo "ERROR: Input file is not a valid gzip file: ${f}"
        exit 1
    fi

    cutadapt \
        -b "file:${meta_fasta}" \
        -e 0 \
        -O 26 \
        --minimum-length 20 \
        --rename='{id} {comment} replicate={adapter_name}' \
        -j "${ncpus}" \
        -o "${pdir}/demultiplexed_CONDITION/{name}_${name_seq%.fastq.gz}_demux_a.fastq.gz" \
        "${f}"

    outputs=( "${pdir}"/demultiplexed_CONDITION/*_"${name_seq%.fastq.gz}"_demux_a.fastq.gz )

    if [ ${#outputs[@]} -eq 0 ]; then
        echo "WARNING: No demultiplexed CONDITION output produced for ${name_seq}. Skipping."
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
        echo "ERROR: All CONDITION outputs were empty or invalid for ${name_seq}"
        exit 1
    fi

    echo "Validated CONDITION output files for ${name_seq}:"
    printf '  %s\n' "${pdir}"/demultiplexed_CONDITION/*_"${name_seq%.fastq.gz}"_demux_a.fastq.gz
done

echo -e "\n\n\n >>> FINISHED DEMULTIPLEX CONDITION <<< \n\n\n"