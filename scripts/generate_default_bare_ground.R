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

source('./my_R/main_utils.R')
source('./my_R/write_bash_submission_mac.R')


################################################################
# specify the important paths and parameters for the simulation.

run_type =  'S0_bare_ground'

generating_path <- "/Users/quan/Models/simulations/ICOS/ED2scenarios"
ref_dir <- paste0(generating_path,"/reference")
rundir <- paste0(generating_path,"/run/",run_type)
outdir <- paste0(generating_path,"/out/",run_type)
if(!dir.exists(rundir)) dir.create(rundir,recursive = TRUE)
if(!dir.exists(outdir)) dir.create(outdir,recursive = TRUE)


Mete_path <- "/Users/quan/Models/simulations/ICOS/Driver/Mete/"
csspss_path <- '/Users/quan/Models/simulations/ICOS/Driver/csspss/'
pft_xml_path <- '/Users/quan/Models/simulations/ICOS/Driver/pft_xml/'

################################################################

csspss_file_list <- list.files(path = csspss_path)
Mete_file_dirs <- list.dirs(Mete_path,full.names = FALSE)
Mete_prefix = 'FLX_'

ED2IN_ref <- file.path(ref_dir,"ED2IN_bare_ground")
ed2in <- read_ed2in(ED2IN_ref)



site_list_df <- read.csv(file = file.path('../Driver/Mete/Data_summary_site.csv'))
site_list <- site_list_df$SITE_ID

###
# css_pss_df <- read.csv(file = file.path(csspss_path,'site_initial_data_overview.csv'))
# css_pss_overview <-css_pss_df %>% select(SITE_ID,time) %>% distinct()

###

################################################################
# Nothing to change from here

list_dir <- list()

for (i_row in seq(1,nrow(site_list_df))) {
  site_id <- site_list_df$SITE_ID[i_row]
  year_a <- site_list_df$YEARA[i_row]
  year_z <- site_list_df$YEARZ[i_row]

  IYEARA = year_a-50
  IYEARZ = year_a-1
  

  name_scenar <- paste("simulation",site_id,IYEARA,IYEARZ,sep = '_')

  run_scenar <- file.path(rundir,name_scenar)
  out_scenar <- file.path(outdir,name_scenar)

  if(!dir.exists(run_scenar)) dir.create(run_scenar)
  if(!dir.exists(out_scenar)) dir.create(out_scenar)
  if(!dir.exists(file.path(out_scenar,"analy"))) dir.create(file.path(out_scenar,"analy"))
  if(!dir.exists(file.path(out_scenar,"histo"))) dir.create(file.path(out_scenar,"histo"))

  #######################################################################################
  # Modify ED2IN
  # Change scenarios
  ed2in_scenar <- ed2in
  # ed2in_scenar$INITIAL_CO2 = CO2[iCO2]
  # ed2in_scenar$TREEFALL_DISTURBANCE_RATE = disturbance[idisturb]

  # set driver
  driver_file_name = Mete_file_dirs[startsWith(Mete_file_dirs,paste0(Mete_prefix,site_id))]
  ed2in_scenar$ED_MET_DRIVER_DB = paste0(Mete_path,driver_file_name,'/ED_MET_DRIVER_HEADER')

  ed2in_scenar$METCYC1 = as.integer(strsplit(sub(paste0(Mete_prefix,site_id),"",driver_file_name),split = '_')[[1]][1])
  ed2in_scenar$METCYCF = as.integer(strsplit(sub(paste0(Mete_prefix,site_id),"",driver_file_name),split = '_')[[1]][2])

  # set spinup time: it should be the a time phrase after the last disturbance
  ed2in_scenar$IYEARA = IYEARA
  ed2in_scenar$IYEARZ = IYEARZ

  # ed2in_scenar$SFILIN = paste0(csspss_path, sub("\\.css$", "", csspss_file_list[startsWith(csspss_file_list,paste0(site_id,'_',year_a))][1]))
  # ed2in_scenar$INCLUDE_THESE_PFT = paste0(unique(css_pss_df$pft[which(css_pss_df$SITE_ID==site_id )]),collapse = ',' )

  # Change output location
  ed2in_scenar$FFILOUT = file.path(out_scenar,"analy","analysis")
  ed2in_scenar$SFILOUT = file.path(out_scenar,"histo","history")

  #######################################################################################
  # Change config
  #######################################################################################
  # ed2in_scenar$IEDCNFGF = file.path(run_scenar,"config.xml")
  # # Modify config
  # system2("cp",c(file.path(ref_dir,"config_black.xml"),
  #                file.path(run_scenar,"config.xml")))

  write_ed2in.ed2in(ed2in_scenar,filename = file.path(run_scenar,"ED2IN"))
  #######################################################################################
  # Modify job.sh

  write_job_mac(file =  file.path(run_scenar,"job.sh"),
                # prerun = "ml UDUNITS/2.2.26-intel-2018a R/3.4.4-intel-2018a-X11-20180131 HDF5/1.10.1-intel-2018a; ulimit -s unlimited",
                prerun = "",
                CD = run_scenar,
                ed_exec = "/Users/quan/Models/CODE/ED2/ED/build/ed_2.2-opt-master-2d4e4d44c",
                ED2IN = "ED2IN")

  list_dir[[name_scenar]]=run_scenar
}


write_bash_submission_mac(
  file = file.path(rundir,"all_jobs.sh"),
  list_files = list_dir,
  job_name = "job.sh",
  max_parallel = 18
)
