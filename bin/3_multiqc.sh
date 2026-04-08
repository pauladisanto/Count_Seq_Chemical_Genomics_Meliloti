#!/usr/bin/env bash

set -euo pipefail

while getopts "p:" flag; do
    case "${flag}" in
        p) pdir="${OPTARG}" ;;
    esac
done

if [ -z "${pdir:-}" ]; then
    echo "ERROR: Please provide -p <project_directory>"
    exit 1
fi

echo ">>> Running MultiQC <<<"

mkdir -p "${pdir}/multiqc"

multiqc "${pdir}" -o "${pdir}/multiqc"

echo ">>> FINISHED MultiQC <<<"
