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

mkdir -p "${pdir}/sequence_cutted"

valid_outputs=0

echo -e "\n\n >>> REMOVE COMMON SEQUENCES <<< \n\n"

shopt -s nullglob
input_files=( "${pdir}"/demultiplexed_CONDITION/*.fastq.gz )

echo "Looking for files in: ${pdir}/demultiplexed_CONDITION"
echo "Pattern: *.fastq.gz"
echo "Number of matching files: ${#input_files[@]}"

if [ ${#input_files[@]} -eq 0 ]; then
    echo "ERROR: No files found matching ${pdir}/demultiplexed_CONDITION/*.fastq.gz"
    exit 1
fi

tmpdir=$(mktemp -d)

cleanup() {
    rm -rf "${tmpdir}"
}
trap cleanup EXIT

for fn in "${input_files[@]}"; do
    name=$(basename "${fn}")
    echo -e "\n\n >> Processing sample ${name} << \n\n"

    if ! gzip -t "${fn}" 2>/dev/null; then
        echo "ERROR: Input file is not a valid gzip file: ${fn}"
        exit 1
    fi

    intermediate="${tmpdir}/${name%.fastq.gz}_adapter5-trimmed.fastq.gz"
    final_out="${pdir}/sequence_cutted/${name%.fastq.gz}_to_quantify.fastq.gz"

    echo "---- Step 1: remove 5' common sequence ----"
    cutadapt \
        -g ^TACTAGCTCTACGACGGTCCACCTAAGCTT \
        -e 0 \
        -j "${ncpus}" \
        -o "${intermediate}" \
        "${fn}"

    if ! gzip -t "${intermediate}" 2>/dev/null; then
        echo "ERROR: Invalid gzip output after 5' trimming: ${intermediate}"
        exit 1
    fi

    intermediate_reads=$(zcat "${intermediate}" | awk 'END {print NR/4}')
    if [ "${intermediate_reads}" -eq 0 ]; then
        echo "WARNING: No reads left after 5' trimming for ${name}. Skipping."
        rm -f "${intermediate}"
        continue
    fi

    echo "---- Step 2: remove sequence after AAGCTT ----"
    cutadapt \
        -a AAGCTT \
        -e 0 \
        -j "${ncpus}" \
        -o "${final_out}" \
        "${intermediate}"

    if ! gzip -t "${final_out}" 2>/dev/null; then
        echo "ERROR: Invalid gzip output after second trimming: ${final_out}"
        exit 1
    fi

    final_reads=$(zcat "${final_out}" | awk 'END {print NR/4}')
    if [ "${final_reads}" -eq 0 ]; then
        echo "WARNING: No reads left after second trimming for ${name}. Removing empty output."
        rm -f "${final_out}"
        continue
    fi

    valid_outputs=$((valid_outputs + 1))

    echo "Saved final trimmed file:"
    echo "  ${final_out}"
    echo "  Reads kept: ${final_reads}"
done

echo "Cleaning empty files and directories..."

find "${pdir}/sequence_cutted" -type f -name "*.fastq.gz" -size 0 -delete
find "${pdir}/sequence_cutted" -type d -empty -delete

if [ "${valid_outputs}" -eq 0 ]; then
    echo "WARNING: No valid sequences were produced in this batch"
fi

echo -e "\n\n\n >>> FINISHED COMMON SEQUENCE REMOVAL <<< \n\n\n"