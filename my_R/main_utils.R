#' Read ED2IN file to named list
#'
#' Parse an ED2IN file to a named list.
#'
#' @param filename Full path to ED2IN file
#' @return Named list of `tag = value`
#' @export
read_ed2in <- function(filename) {
  raw_file <- readLines(filename)

  # Extract tag-value pairs
  ed2in_tag_rxp <- paste0(
    "^[[:blank:]]*",              # Initial whitespace (does not start with a `!` comment)
    "NL%([[:graph:]]+)",          # Capture namelist tag (1)
    "[[:blank:]]+=[[:blank:]]*",  # Equals, with optional surrounding whitespace
    "(",                          # Begin value capture (2)
    "[[:digit:].-]+(,[[:blank:]]*[[:digit:].-]+)*",   # Number, or number list
    "|",                          # ...or...
    "@.*?@",                      # Old substitution tag (e.g. @MYVALUE@)
    "|",                          # ...or...
    "'[[:graph:][:blank:]]*'",    # Quoted string, or list of strings
    ")",                          # End value capture
    "[[:blank:]]*!?.*$"           # Trailing whitespace and possible comments
  )

  tag_lines <- grep(ed2in_tag_rxp, raw_file, perl = TRUE)
  sub_file <- raw_file[tag_lines]
  tags <- gsub(ed2in_tag_rxp, "\\1", sub_file, perl = TRUE)
  values <- gsub(ed2in_tag_rxp, "\\2", sub_file, perl = TRUE)

  # Extract comments. They will be stored in the object attributes.
  all_lines <- seq_along(raw_file)
  comment_linenos <- all_lines[!all_lines %in% tag_lines]
  comment_values <- raw_file[comment_linenos]

  # Convert to a list to allow storing of multiple data types
  values_list <- as.list(values)

  # NOTE: code below relies on as.numeric() coercing values to NA
  numeric_values <- !is.na(suppressWarnings(as.numeric(values))) |
    grepl("^@.*?@$", values)    # Unquoted old substitutions are numeric
  #check for old substitution tags
  if (any(grepl("^@.*?@$", values))) {
    cat("Old substitution tags present in ED2IN file")
  }
  values_list[numeric_values] <- suppressWarnings(lapply(values_list[numeric_values], as.numeric))

  # Convert values that are a list of numbers to a numeric vector
  numlist_values <- grep(
    "[[:digit:].-]+(,[[:blank:]]*[[:digit:].-]+)+",
    values
  )
  values_list[numlist_values] <- lapply(
    values_list[numlist_values],
    function(x) as.numeric(strsplit(x, split = ",")[[1]])
  )

  # Convert values that are a list of strings to a character vector
  charlist_values <- grep("'.*?'(,'.*?')+", values)
  values_list[charlist_values] <- lapply(
    values_list[charlist_values],
    function(x) strsplit(x, split = ",")[[1]]
  )

  # Remove extra quoting of strings
  quoted_values <- grep("'.*?'", values)
  values_list[quoted_values] <- lapply(
    values_list[quoted_values],
    gsub,
    pattern = "'",
    replacement = ""
  )

  structure(
    values_list,
    names = tags,
    class = c("ed2in", "list"),
    comment_linenos = comment_linenos,
    comment_values = comment_values,
    value_linenos = tag_lines
  )
}

#' Print method for `ed2in`
#'
#' Sets attributes to `NULL` before printing, so the output isn't as messy.
#'
#' @inheritParams base::print
#'
#' @export
print.ed2in <- function(x, ...) {
  attributes(x) <- attributes(x)["names"]
  print.default(x, ...)
}

#' Check if object is `ed2in`
#'
#' Simple test if object inheirts from class `"ed2in"`.
#'
#' @param x Object to be tested
#' @export
is.ed2in <- function(x) {
  inherits(x, "ed2in")
}

#' Write ED2IN list to file
#'
#' This writes a ED2IN file from an `ed2in` list. Default method writes a
#' barebones file without comments. S3 method for `ed2in` objects extracts
#' comments and their locations from the object attributes (if `barebones` is
#' `FALSE`).
#'
#' @param ed2in Named list of ED2IN tag-value pairs. See [read_ed2in].
#' @param filename Target file name
#' @param custom_header Character vector for additional header comments. Each
#' item gets its own line.
#' @param barebones Logical. If `TRUE`, omit comments and only write tag-value pairs.
#' @export
write_ed2in <- function(ed2in, filename, custom_header = character(), barebones = FALSE) {
  UseMethod("write_ed2in", ed2in)
}

#' @rdname write_ed2in
#' @export
write_ed2in.ed2in <- function(ed2in, filename, custom_header = character(), barebones = FALSE) {
  tags_values_vec <- tags2char(ed2in)
  if (isTRUE(barebones)) {
    write_ed2in.default(ed2in, filename, custom_header, barebones)
    return(NULL)
  }
  nvalues <- length(tags_values_vec)
  ncomments <- length(attr(ed2in, "comment_values"))
  file_body <- character(nvalues + ncomments)
  file_body[attr(ed2in, "comment_linenos")] <-
    attr(ed2in, "comment_values")
  file_body[attr(ed2in, "value_linenos")] <-
    tags_values_vec[1:length(attr(ed2in, "value_linenos"))]

  #check for new tags
  if(length(tags_values_vec) > length(attr(ed2in, "value_linenos"))) {
    #find the $END
    END_line <- grep("\\$END", file_body) - 1
    new_tags <-
      tags_values_vec[(length(attr(ed2in, "value_linenos")) + 1):length(tags_values_vec)]
    #put the new tags in with $END at the end
    file_body <- c(file_body[1:END_line], new_tags, "$END")
  }
  header <- c(
    "!=======================================",
    "!=======================================",
    "!  ED2 namelist file",
    "!  Generated by `PEcAn.ED2::write_ed2in.ed2in`",
    "!  Additional user comments below: ",
    paste0("!   ", custom_header),
    "!---------------------------------------"
  )
  output_lines <- c(header, file_body)
  writeLines(output_lines, filename)
}

#' @rdname write_ed2in
#' @export
write_ed2in.default <- function(ed2in, filename, custom_header = character(), barebones = FALSE) {
  tags_values_vec <- tags2char(ed2in)
  header <- c(
    "!=======================================",
    "!=======================================",
    "!  ED2 namelist file",
    "!  Generated by `PEcAn.ED2::write_ed2in.default`",
    "!  Additional user comments below: ",
    paste0("!   ", custom_header),
    "!---------------------------------------"
  )
  output_lines <-
    c(
      header,
      "$ED_NL",
      tags_values_vec,
      "$END",
      "!==========================================================================================!",
      "!==========================================================================================!"
    )
  writeLines(output_lines, filename)
}

#' Format ED2IN tag-value list
#'
#' Converts an `ed2in`-like list to an ED2IN-formatted character vector.
#'
#' @inheritParams write_ed2in
tags2char <- function(ed2in) {
  char_values <- vapply(ed2in, is.character, logical(1))
  na_values <- vapply(ed2in, function(x) all(is.na(x)), logical(1))
  quoted_vals <- ed2in
  quoted_vals[char_values] <- lapply(quoted_vals[char_values], shQuote)
  quoted_vals[na_values] <- lapply(quoted_vals[na_values], function(x) "")
  values_vec <- vapply(quoted_vals, paste, character(1), collapse = ",")
  tags_values_vec <- sprintf("   NL%%%s = %s", names(values_vec), values_vec)
  tags_values_vec
}



# Generated from function body. Editing this file has no effect.
write_job_mac <- function(file = file.path(getwd(),"job.sh"),
                      # nodes = 1,ppn = 18,mem = 16,walltime = 24,
                      prerun = "ml UDUNITS/2.2.26-intel-2018a R/3.4.4-intel-2018a-X11-20180131 HDF5/1.10.1-intel-2018a; ulimit -s unlimited",
                      CD = "/user/scratchkyukon/gent/gvo000/gvo00074/felicien/ED2/ED/run",
                      ed_exec = "/user/scratchkyukon/gent/gvo000/gvo00074/felicien/ED2/ED/run/ed_2.1-opt",
                      ED2IN = "ED2IN",
                      if_post = TRUE,if_plot = TRUE,
                      Rplot_function = '/Users/quan/Models/R/read_and_plot_ED2_Q2R_tspft.r',
                      clean = FALSE,
                      in.line = ''){

  ed2in <- read_ed2in(file.path(CD,ED2IN))
  DN <- dirname(ed2in$FFILOUT)
  analy <- basename(ed2in$FFILOUT)
  init <- paste(ed2in$IYEARA,sprintf('%02d',ed2in$IMONTHA),sprintf('%02d',ed2in$IDATEA),sep='/')
  end <- paste(ed2in$IYEARZ,sprintf('%02d',ed2in$IMONTHZ),sprintf('%02d',ed2in$IDATEZ),sep='/')
  Rfunction <- tools::file_path_sans_ext(basename(Rplot_function))

  writeLines("#!/bin/bash -l",con = file)
  # write(paste0("#PBS -l nodes=",nodes,":ppn=",ppn),file=file,append=TRUE)
  # write(paste0("#PBS -l mem=",mem,"gb"),file=file,append=TRUE)
  # write(paste0("#PBS -l walltime=",walltime,":00:00"),file=file,append=TRUE)
  write("",file=file,append=TRUE)
  write(prerun,file=file,append=TRUE)
  write("",file=file,append=TRUE)
  write(paste("cd",CD),file=file,append=TRUE)
  write("",file=file,append=TRUE)
  write(paste(ed_exec,"-f",ED2IN),file=file,append=TRUE)
  write("",file=file,append=TRUE)

  write(in.line,file=file,append=TRUE)

  if (if_post) {
    r_script <- sub("\\.sh$", ".R", file)
    
    ## 1️⃣ 先写固定模板
    writeLines(c(
      "library(akima)",
      "source('/Users/quan/Models/simulations/ICOS/post_process/R/h5read_opt.r')",
      "source('/Users/quan/Models/simulations/ICOS/post_process/R/read_and_save_ED2.2.R')",
      "source('/Users/quan/Models/simulations/ICOS/post_process/R/read_save_plot_ED2.2.R')",
      "ED_utils_dir = '/Users/quan/Models/simulations/ICOS/post_process/R-utils'"
    ), con = r_script)
    
    ## 2️⃣ 保留你的“灵活接口”
    
    if  (if_plot) {
      write(
        paste0(
          'read_and_plot_ED2_Q2R', "('",
          DN, "','",
          analy, "','",
          init, "','",
          end, "')"
        ),
        file = r_script,
        append = TRUE
      )
    } else {
      write(
        paste0(
          'read_and_save_ED2.2', "('",
          DN, "','",
          analy, "','",
          init, "','",
          end, "')"
        ),
        file = r_script,
        append = TRUE
      )
    }
    
    ## 4️⃣ 写 shell 调用
    write(
      paste0("Rscript ", r_script),
      file = file,
      append = TRUE
    )
  }

  if (clean){
    ed2in <- read_ed2in(file.path(CD,ED2IN))
    OPfiles <- ed2in$FFILOUT
    CMD <- paste0("rm $(find ",paste0(OPfiles,"-Q-*")," -name '*' ! -name '",paste0(basename(OPfiles),"-Q*-","01","-*"),"')")
    write(CMD,file=file,append=TRUE)
  }
}


# Generated from function body. Editing this file has no effect.
write_bash_submission_mac <- function (file = file.path(getwd(), "all_jobs.sh"), list_files = list(), 
    job_name = "job.sh", max_parallel = 4) 
  {
      writeLines("#!/bin/bash -l", con = file)
      write("START_TIME=$(date +%s)", file = file, append = TRUE)
      write("", file = file, append = TRUE)
      bash_functions <- c("# 定义并行控制函数", "limit_jobs() {", 
          "    while [ $(jobs -r | wc -l) -ge $1 ]; do", "        sleep 10", 
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

