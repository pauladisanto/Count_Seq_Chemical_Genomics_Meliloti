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

    tmp="${name_seq%_trimmed_merged_demux.fastq.gz}"
    pool_name="${tmp%%_*}"
    ngs_name="${tmp#*_}"

    echo "Detected POOL: ${pool_name}"
    echo "Detected NGS_name: ${ngs_name}"

    if [ "${pool_name}" = "unknown" ]; then
        echo "WARNING: Skipping unknown pool file: ${name_seq}"
        continue
    fi

    sample_fasta="${pdir}/demultiplexed_CONDITION/${pool_name}_${ngs_name}_metadata_R.fasta"

    awk -v pool="${pool_name}" -v sample="${ngs_name}" '
    BEGIN {
        keep = 0
    }

    /^>/ {
        header = substr($0, 2)
        split(header, parts, "__")

        this_pool  = parts[1]
        this_rep   = parts[2]
        this_label = parts[3]
        this_ngs   = parts[4]

        if (this_pool == pool && this_ngs == sample) {
            keep = 1
            current_header = this_rep "_" this_label
        } else {
            keep = 0
        }
        next
    }

    keep {
        seq = $0
        gsub(/ /, "", seq)

        if (!(seq in seen_seq)) {
            print ">" current_header
            print seq
            seen_seq[seq] = 1
        }
        keep = 0
    }
    ' "${meta_fasta}" > "${sample_fasta}"

    if [ ! -s "${sample_fasta}" ]; then
        echo "WARNING: No matching reverse metadata entries found for POOL=${pool_name}, NGS_name=${ngs_name}. Skipping."
        rm -f "${sample_fasta}"
        continue
    fi

    echo "Using reverse metadata entries:"
    grep "^>" "${sample_fasta}" || true

    if ! gzip -t "${f}" 2>/dev/null; then
        echo "ERROR: Input file is not a valid gzip file: ${f}"
        exit 1
    fi

    rm -f "${pdir}"/demultiplexed_CONDITION/*_"${name_seq%.fastq.gz}"_demux_a.fastq.gz

    cutadapt \
        -a "file:${sample_fasta}" \
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

    for out in "${outputs[@]}"; do
        if [ ! -s "${out}" ]; then
            echo "WARNING: Output file is empty: ${out}. Removing and continuing."
            rm -f "${out}"
            continue
        fi

        if ! gzip -t "${out}" 2>/dev/null; then
            echo "ERROR: Invalid gzip output produced: ${out}"
            exit 1
        fi
    done
done

echo -e "\n\n\n >>> FINISHED DEMULTIPLEX CONDITION <<< \n\n\n"