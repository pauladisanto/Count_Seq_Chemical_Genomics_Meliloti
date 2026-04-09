nextflow.enable.dsl=2

params.input_dir         = null
params.metadata_f        = null
params.metadata_r        = null
params.salmon_fasta      = null

if ( !params.input_dir ) {
    error "Please provide --input_dir"
}

if ( !params.metadata_f ) {
    error "Please provide --metadata_f"
}

if ( !params.metadata_r ) {
    error "Please provide --metadata_r"
}

if ( !params.salmon_fasta ) {
    error "Please provide --salmon_fasta"
}

workflow {
    Channel.of(params.input_dir).set { input_dir_ch }
    Channel.of(params.metadata_f).set { metadata_f_ch }
    Channel.of(params.metadata_r).set { metadata_r_ch }
    Channel.of(params.salmon_fasta).set { salmon_fasta_ch }

    made_dirs    = CREATE_DIRS(input_dir_ch)
    qc_done      = QC_AND_TRIMMING(made_dirs)
    merged       = BBMERGE_READS(qc_done)
    meta_done    = PREPARE_METADATA_FASTA(metadata_f_ch.combine(metadata_r_ch).combine(merged))
    demux1       = DEMULTIPLEX_POOL(meta_done)
    demux2       = DEMULTIPLEX_CONDITION(demux1)
    cleaned      = REMOVE_COMMON_SEQUENCES(demux2)

    salmon_index = BUILD_SALMON_INDEX(salmon_fasta_ch)
    quants       = QC_SALMON(cleaned.combine(salmon_index))
    collected    = COLLECT_GOOD_QUANTS(quants)

    report       = RUN_MULTIQC(quants)
}

process CREATE_DIRS {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    mkdir -p "${input_dir}/fastqc"
    mkdir -p "${input_dir}/trimmed"
    mkdir -p "${input_dir}/merged"
    mkdir -p "${input_dir}/demultiplexed_POOL"
    mkdir -p "${input_dir}/demultiplexed_CONDITION"
    mkdir -p "${input_dir}/sequence_cutted"
    mkdir -p "${input_dir}/quants"
    mkdir -p "${input_dir}/multiqc"
    """
}

process QC_AND_TRIMMING {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/2_qc_and_trimming.sh -p "${input_dir}"
    """
}

process BBMERGE_READS {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/5_bbmerge.sh -p "${input_dir}"
    """
}

process PREPARE_METADATA_FASTA {

    tag "${input_dir}"

    input:
    tuple val(metadata_f), val(metadata_r), val(input_dir)

    output:
    val input_dir

    script:
    """
    cp "${metadata_f}" "${input_dir}/metadata_F.fasta"
    cp "${metadata_r}" "${input_dir}/metadata_R.fasta"
    """
}

process DEMULTIPLEX_POOL {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/6_demultiplex_cutadapt.sh -p "${input_dir}"
    """
}

process DEMULTIPLEX_CONDITION {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/7_demultiplex_condition.sh -p "${input_dir}"
    """
}

process REMOVE_COMMON_SEQUENCES {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/8_remove_common_sequences.sh -p "${input_dir}"
    """
}

process BUILD_SALMON_INDEX {

    tag "salmon_index"

    input:
    val salmon_fasta

    output:
    val "${projectDir}/salmon_index/H_signatures_unique"

    script:
    """
    mkdir -p "${projectDir}/salmon_index"

    salmon index \
        -t "${salmon_fasta}" \
        -i "${projectDir}/salmon_index/H_signatures_unique" \
        -k 21
    """
}

process QC_SALMON {

    tag "${input_dir}"

    input:
    tuple val(input_dir), val(salmon_index)

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/9_qc_salmon.sh -p "${input_dir}" -i "${salmon_index}"
    """
}

process RUN_MULTIQC {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/3_multiqc.sh -p "${input_dir}"
    """
}

process COLLECT_GOOD_QUANTS {

    tag "${input_dir}"

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    python3 ${projectDir}/bin/10_collect_good_quants.py -p "${input_dir}"
    """
}