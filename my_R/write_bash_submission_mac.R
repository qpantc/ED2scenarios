# Generated from function body. Editing this file has no effect.
function (file = file.path(getwd(), "all_jobs.sh"), list_files = list(), 
    job_name = "job.sh", max_parallel = 4) 
{
    writeLines("#!/bin/bash -l", con = file)
    write("START_TIME=$(date +%s)", file = file, append = TRUE)
    write("", file = file, append = TRUE)
    bash_functions <- c("# 定义并行控制函数", "limit_jobs() {", 
        "    while [ $(jobs -r | wc -l) -ge $1 ]; do", "        sleep 1", 
        "    done", "}", paste0("MAX_JOBS=", max_parallel))
    write(bash_functions, file = file, append = TRUE)
    write("", file = file, append = TRUE)
    if (length(job_name) == 1) 
        job_name <- rep(job_name, length(list_files))
    tryCatch({
        for (i in 1:length(list_files)) {
            write(paste("cd", list_files[[i]]), file = file, 
                append = TRUE)
            write("limit_jobs $MAX_JOBS", file = file, append = TRUE)
            write(paste("bash", job_name[i], "&"), file = file, 
                append = TRUE)
            write(paste("echo 'Started job", i, "in", list_files[[i]], 
                "'"), file = file, append = TRUE)
        }
    }, error = function(e) {
        message("Error occurred: ", e$message)
    })
    write("wait", file = file, append = TRUE)
    timing_code <- c("END_TIME=$(date +%s)", "ELAPSED_TIME=$((END_TIME - START_TIME))", 
        "echo '=================================='", "echo 'All jobs completed.'", 
        "echo \"Total runtime: ${ELAPSED_TIME} seconds\"", "echo \"Total runtime: $((ELAPSED_TIME / 60)) minutes and $((ELAPSED_TIME % 60)) seconds\"")
    write(timing_code, file = file, append = TRUE)
    return(TRUE)
}
