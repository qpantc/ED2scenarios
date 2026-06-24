rm(list = ls())
setwd("/Users/quan/Models/simulations/ICOS/ED2scenarios")

# library(PEcAn.ED2)
# library(remotes)
# remotes::install_github("femeunier/ED2scenarios")
# install_github('pecanproject/pecan',  subdir = "models/ed")
# install.packages('rlist')

library(rlist)
library(purrr)
library(tidyverse)
library(ED2scenarios)


################################################################
source('./my_R/main_utils.R')
source('./my_R/write_bash_submission_mac.R')
simulation_list_df <- read.csv(file = './scripts/simulation_list_S0-S6.csv')
Mete_path <- "/Volumes/Sd1TB/MODEL_DRIVER/ED2/ICOS/Mete/" 
csspss_path <- '/Volumes/Sd1TB/MODEL_DRIVER/ED2/ICOS/csspss' # 结尾不带/
config_path <- '/Volumes/Sd1TB/MODEL_DRIVER/ED2/ICOS/config' # 结尾不带/
################################################################
Mete_file_dirs <- list.dirs(Mete_path,full.names = FALSE)
Mete_prefix = 'FLX_'

################################################################
# specify the important paths and parameters for the simulation.

# run_type =  'S0'




################################################################
###################### Create jobs   ###########################
################################################################
run_type_list <- c('S0') #,'S1','S2','S3','S4','S5','S6'
list_dir <- list()
for(run_type in run_type_list){

  working_dir <- file.path(getwd())
  ref_dir <- file.path(working_dir,".reference")
  rundir <- file.path(working_dir,'run',run_type)
  outdir <- file.path(working_dir,'out',run_type)
  if(!dir.exists(rundir)) dir.create(rundir,recursive = TRUE)
  if(!dir.exists(outdir)) dir.create(outdir,recursive = TRUE)

  simulations_ids <- simulation_list_df %>% filter(TYPE == run_type) %>% pull(simulation_id)

  for(simulation_i in simulations_ids){
    simulation_i_df <- simulation_list_df %>% filter(simulation_id == simulation_i)


    site_id <- simulation_i_df$SITE_ID[1]

    IYEARA = simulation_i_df$IYEARA[1]
    IYEARZ = simulation_i_df$IYEARZ[1]

    name_scenar <- paste("simulation",site_id,IYEARA,IYEARZ,sep = '_')

    # set run and output directories
    run_scenar <- file.path(rundir,name_scenar)
    out_scenar <- file.path(outdir,name_scenar)
    if(!dir.exists(run_scenar)) dir.create(run_scenar)
    if(!dir.exists(out_scenar)) dir.create(out_scenar)

    #######################################################################################
    # Modify ED2IN
    #######################################################################################

    # 1. Set scenarios using reference ED2IN file
    #=====================================================================================
    if (run_type == 'S0') {
      ED2IN_ref <- file.path(ref_dir,"ED2IN_bare_ground")
      ed2in_scenar <- read_ed2in(ED2IN_ref)
      ed2in_scenar$IED_INIT_MODE = 0

    } else if (run_type %in% c('S4', 'S5')) {
      ED2IN_ref <- file.path(ref_dir,"ED2IN_flux_site")
      ed2in_scenar <- read_ed2in(ED2IN_ref)
      ed2in_scenar$IED_INIT_MODE = 1

      ed2in_scenar$SFILIN = sub("\\.css$", "", file.path(csspss_path, simulation_i_df$parameter_file,paste0(site_id,'.css')))
    } 

    # 2. Set run and output directories
    #=====================================================================================
    # Set output location
    ed2in_scenar$FFILOUT = file.path(out_scenar,"analy","analysis")
    ed2in_scenar$SFILOUT = file.path(out_scenar,"histo","history")
    if(!dir.exists(file.path(out_scenar,"analy"))) dir.create(file.path(out_scenar,"analy"))
    if(!dir.exists(file.path(out_scenar,"histo"))) dir.create(file.path(out_scenar,"histo"))
    

    # 3. Set climatic drivers and simulation time
    #=====================================================================================
    # Set simulation time: it should be the a time phrase after the last disturbance
    ed2in_scenar$IYEARA = IYEARA
    ed2in_scenar$IYEARZ = IYEARZ
    # set mete driver
    driver_file_name = Mete_file_dirs[startsWith(Mete_file_dirs,paste0(Mete_prefix,site_id))]
    ed2in_scenar$ED_MET_DRIVER_DB = paste0(Mete_path,driver_file_name,'/ED_MET_DRIVER_HEADER')
    if(run_type == 'S0') {
      ed2in_scenar$METCYC1 = as.integer(strsplit(sub(paste0(Mete_prefix,site_id),"",driver_file_name),split = '_')[[1]][1])
      ed2in_scenar$METCYCF = as.integer(strsplit(sub(paste0(Mete_prefix,site_id),"",driver_file_name),split = '_')[[1]][2])
    }

    # 4. Set PFTs and PFT parameters
    #=====================================================================================
    ed2in_scenar$INCLUDE_THESE_PFT = as.numeric(strsplit(simulation_i_df$INCLUDE_THESE_PFT, "_")[[1]])
    file.copy(from = file.path(config_path, simulation_i_df$parameter_file, paste0(site_id, '.xml')),
          to = file.path(run_scenar, "config.xml"),
          overwrite = TRUE)
    ed2in_scenar$IEDCNFGF = file.path(run_scenar,"config.xml")

    # 5. Other experimental setting
    #=====================================================================================
    # ed2in_scenar$INITIAL_CO2 = CO2[iCO2]
    # ed2in_scenar$TREEFALL_DISTURBANCE_RATE = disturbance[idisturb]


    #=====================================================================================
    # 6. write ED2IN
    #=====================================================================================
    write_ed2in.ed2in(ed2in_scenar,filename = file.path(run_scenar,"ED2IN"))

    #=====================================================================================
    # 7.Modify job.sh
    #=====================================================================================

    write_job_mac(file =  file.path(run_scenar,"job.sh"),
                  # prerun = "ml UDUNITS/2.2.26-intel-2018a R/3.4.4-intel-2018a-X11-20180131 HDF5/1.10.1-intel-2018a; ulimit -s unlimited",
                  prerun = "",
                  CD = run_scenar,
                  ed_exec = "/Users/quan/Models/CODE/ED2/ED/build/ed_2.2-opt-master-2d4e4d44c",
                  if_post = TRUE,if_plot = TRUE,
                  ED2IN = "ED2IN")

    list_dir[[name_scenar]]=run_scenar
  }
}

write_bash_submission_mac(
  file = file.path(rundir,"all_jobs.sh"),
  list_files = list_dir,
  job_name = "job.sh",
  max_parallel = 6
)
