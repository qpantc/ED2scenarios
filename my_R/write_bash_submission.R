write_bash_submission <- function(file = file.path(getwd(),"all_jobs.sh"),
                                  list_files = list(),
                                  job_name = "job.sh"){

  writeLines("#!/bin/bash -l",con = file)

  if (length(job_name) == 1) job_name <- rep(job_name,length(list_files))

  tryCatch(map(1:length(list_files),function(i){
    write(paste("cd",list_files[[i]]),file=file,append=TRUE)
    write(paste("qsub",job_name[i]),file=file,append=TRUE)
  }),error = function(e) e)

  return(TRUE)
}

write_bash_submission_mac <- function(file = file.path(getwd(), "all_jobs.sh"),
                                      list_files = list(),
                                      job_name = "job.sh",
                                      max_parallel = 4) {

  # 1. 写入文件头
  writeLines("#!/bin/bash -l", con = file)

  # 2. 记录开始时间
  # 使用 date +%s 获取秒级时间戳
  write("START_TIME=$(date +%s)", file = file, append = TRUE)
  write("", file = file, append = TRUE) # 空行

  # 3. 写入并行控制函数
  bash_functions <- c(
    "# 定义并行控制函数",
    "limit_jobs() {",
    "    while [ $(jobs -r | wc -l) -ge $1 ]; do",
    "        sleep 1",
    "    done",
    "}",
    paste0("MAX_JOBS=", max_parallel)
  )

  write(bash_functions, file = file, append = TRUE)
  write("", file = file, append = TRUE) # 空行

  if (length(job_name) == 1) job_name <- rep(job_name, length(list_files))

  # 4. 循环写入任务
  tryCatch({
    for (i in 1:length(list_files)) {
      # 1. 进入目录
      write(paste("cd", list_files[[i]]), file = file, append = TRUE)

      # 2. 检查是否有空位
      write("limit_jobs $MAX_JOBS", file = file, append = TRUE)

      # 3. 后台运行任务 (&)
      write(paste("bash", job_name[i], "&"), file = file, append = TRUE)

      # 4. 打印状态 (可选)
      write(paste("echo 'Started job", i, "in", list_files[[i]], "'"), file = file, append = TRUE)
    }
  }, error = function(e) {
    message("Error occurred: ", e$message)
  })

  # 5. 脚本末尾：等待、计算时间并输出
  write("wait", file = file, append = TRUE)

  # 计算时长的 Bash 逻辑
  timing_code <- c(
    "END_TIME=$(date +%s)",
    "ELAPSED_TIME=$((END_TIME - START_TIME))",
    "echo '=================================='",
    "echo 'All jobs completed.'",
    "echo \"Total runtime: ${ELAPSED_TIME} seconds\"",
    "echo \"Total runtime: $((ELAPSED_TIME / 60)) minutes and $((ELAPSED_TIME % 60)) seconds\""
  )

  write(timing_code, file = file, append = TRUE)

  return(TRUE)
}
