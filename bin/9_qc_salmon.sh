#!/usr/bin/env bash

set -euo pipefail

ncpus=7

while getopts "p:i:" flag; do
    case "${flag}" in
        p) pdir="${OPTARG}" ;;
        i) uptag_index="${OPTARG}" ;;
        *)
            echo "Usage: $0 -p <project_directory> -i <salmon_index>"
            exit 1
            ;;
    esac
done

if [ -z "${pdir:-}" ]; then
    echo "ERROR: Please provide -p <project_directory>"
    exit 1
fi

if [ -z "${uptag_index:-}" ]; then
    echo "ERROR: Please provide -i <salmon_index>"
    exit 1
fi

samp=$(basename "${pdir}")
seq_dir="${pdir}/sequence_cutted"
quant_root="${pdir}/quants"

echo ">>> Processing batch ${samp} <<<"

mkdir -p "${quant_root}"

echo -e "\n\n\n >>> SALMON QUANTIFICATION PER FILE <<< \n\n\n"

if [ ! -d "${seq_dir}" ]; then
    echo "ERROR: Directory not found: ${seq_dir}"
    exit 1
fi

mapfile -t input_files < <(find "${seq_dir}" -maxdepth 1 -type f -name "*.fastq.gz" | sort)

echo "Looking for files in: ${seq_dir}"
echo "Pattern: *.fastq.gz"
echo "Number of matching files: ${#input_files[@]}"

if [ ${#input_files[@]} -eq 0 ]; then
    echo "ERROR: No files found under ${seq_dir}"
    exit 1
fi

for fn in "${input_files[@]}"; do
    name=$(basename "${fn}")
    sample_name="${name%.fastq.gz}"
    outdir="${quant_root}/${sample_name}"

    echo -e "\n\n # Processing file ${name} # \n\n"

    # Always create one output folder per input file
    mkdir -p "${outdir}"

    if ! gzip -t "${fn}" 2>/dev/null; then
        echo "FAILED: Input FASTQ is not a valid gzip file: ${fn}" | tee "${outdir}/STATUS.txt"
        continue
    fi

    echo "Input file: ${fn}"
    echo "Quant output dir: ${outdir}"

    if salmon quant \
        -i "${uptag_index}" \
        -l A \
        -r "${fn}" \
        -p "${ncpus}" \
        --validateMappings \
        --noLengthCorrection \
        --minAssignedFrags 1 \
        --output "${outdir}"
    then
        if [ -f "${outdir}/quant.sf" ]; then
            echo "OK: quantification completed" > "${outdir}/STATUS.txt"
        else
            echo "FAILED: salmon finished but quant.sf missing" > "${outdir}/STATUS.txt"
        fi
    else
        echo "FAILED: salmon quant failed" > "${outdir}/STATUS.txt"
    fi
done

echo -e "\n\n\n >>> FINISHED SALMON <<< \n\n\n"