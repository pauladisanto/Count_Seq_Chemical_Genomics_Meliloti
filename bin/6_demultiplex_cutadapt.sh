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
    merged_name=$(basename "${merged}")
    ngs_name="${merged_name%_trimmed_merged.fastq.gz}"

    echo "Processing merged file: ${merged_name}"
    echo "Detected NGS_name: ${ngs_name}"

    if ! gzip -t "${merged}" 2>/dev/null; then
        echo "ERROR: Input merged file is not a valid gzip file: ${merged}"
        exit 1
    fi

    sample_fasta="${pdir}/demultiplexed_POOL/${ngs_name}_metadata_F.fasta"

    awk -v sample="${ngs_name}" '
    BEGIN {
        keep = 0
    }
    /^>/ {
        header = substr($0,2)

        if (header ~ "_" sample "$") {
            keep = 1
            sub("_" sample "$", "", header)
            current_header = header
        } else {
            keep = 0
        }
        next
    }
    keep {
        seq = $0
        gsub(/ /, "", seq)

        key = current_header "\t" seq

        if (!(key in seen)) {
            print ">" current_header
            print seq
            seen[key] = 1
        }
        keep = 0
    }
    ' "${meta_fasta}" > "${sample_fasta}"

    if [ ! -s "${sample_fasta}" ]; then
        echo "ERROR: No matching metadata entries found for ${ngs_name} in ${meta_fasta}"
        exit 1
    fi

    echo "Using metadata entries:"
    grep "^>" "${sample_fasta}"

    rm -f "${pdir}"/demultiplexed_POOL/*_"${ngs_name}"_trimmed_merged_demux.fastq.gz

    cutadapt \
        -g "file:${sample_fasta}" \
        -e 0 \
        -O 26 \
        --rename='{id} {comment} sample={adapter_name}' \
        --rc \
        -j "${ncpus}" \
        -o "${pdir}/demultiplexed_POOL/{name}_${ngs_name}_trimmed_merged_demux.fastq.gz" \
        "${merged}"

    sample_outputs=( "${pdir}"/demultiplexed_POOL/*_"${ngs_name}"_trimmed_merged_demux.fastq.gz )

    if [ ${#sample_outputs[@]} -eq 0 ]; then
        echo "ERROR: No demultiplexed output files were produced for ${ngs_name}"
        exit 1
    fi

    for out in "${sample_outputs[@]}"; do
        if [ ! -s "${out}" ]; then
            echo "ERROR: Output file is empty: ${out}"
            exit 1
        fi

        if ! gzip -t "${out}" 2>/dev/null; then
            echo "ERROR: Invalid gzip output produced: ${out}"
            exit 1
        fi
    done

    echo "Validated output files for ${ngs_name}:"
    printf '  %s\n' "${sample_outputs[@]}"
done

echo -e "\n\n\n >>> FINISHED DEMULTIPLEX <<< \n\n\n"