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

println "Config file ncpus = ${params.ncpus}"
println "Config file trim_quality = ${params.trim_quality}"
println "cutadapt_error_rate = ${params.cutadapt_error_rate}"
println "cutadapt_overlap    = ${params.cutadapt_overlap}"
println "condition_error_rate = ${params.condition_error_rate}"
println "condition_overlap    = ${params.condition_overlap}"
println "condition_min_length = ${params.condition_min_length}"
println "salmon_libtype             = ${params.salmon_libtype}"
println "salmon_min_assigned_frags  = ${params.salmon_min_assigned_frags}"
println "common_5prime_sequence = ${params.common_5prime_sequence}"
println "common_3prime_sequence = ${params.common_3prime_sequence}"
println "common_error_rate      = ${params.common_error_rate}"

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
    cpus params.ncpus

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/qc_and_trimming.sh \
        -p "${input_dir}" \
        -t ${task.cpus} \
        -q ${params.trim_quality}
    """
}

process BBMERGE_READS {

    tag "${input_dir}"

    cpus params.ncpus

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/bbmerge.sh \
        -p "${input_dir}" \
        -t ${task.cpus}
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
    cpus params.ncpus

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/demultiplex_cutadapt.sh \
        -p "${input_dir}" \
        -t ${task.cpus} \
        -e ${params.cutadapt_error_rate} \
        -O ${params.cutadapt_overlap}
    """
}

process DEMULTIPLEX_CONDITION {

    tag "${input_dir}"
    cpus params.ncpus

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/demultiplex_condition.sh \
        -p "${input_dir}" \
        -t ${task.cpus} \
        -e ${params.condition_error_rate} \
        -O ${params.condition_overlap} \
        -m ${params.condition_min_length}
    """
}

process REMOVE_COMMON_SEQUENCES {

    tag "${input_dir}"
    cpus params.ncpus

    input:
    val input_dir

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/remove_common_sequences.sh \
        -p "${input_dir}" \
        -t ${task.cpus} \
        -g ${params.common_5prime_sequence} \
        -a ${params.common_3prime_sequence} \
        -e ${params.common_error_rate}
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
    cpus params.ncpus

    input:
    tuple val(input_dir), val(salmon_index)

    output:
    val input_dir

    script:
    """
    bash ${projectDir}/bin/qc_salmon.sh \
        -p "${input_dir}" \
        -i "${salmon_index}" \
        -t ${task.cpus} \
        -l ${params.salmon_libtype} \
        -m ${params.salmon_min_assigned_frags}
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
    bash ${projectDir}/bin/multiqc.sh -p "${input_dir}"
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
    python3 ${projectDir}/bin/collect_good_quants.py -p "${input_dir}"
    """
}