rm(list = ls())


# library(PEcAn.ED2)
# library(remotes)
# install_github('pecanproject/pecan',  subdir = "models/ed")
library(rlist)
library(purrr)
library(tidyverse)
library(ED2scenarios)
# source('./R/read_ed2in.R')
# source('./R/write_ed2in.R')
working_dir <- "/Users/quan/Models/simulations/ICOS/ED2scenarios"
setwd(working_dir)
source('./my_R/main_utils.R')
source('./my_R/write_bash_submission_mac.R')

################################################################
# specify the important paths and parameters for the simulation.

run_type =  'S4'


ref_dir <- file.path(working_dir,"reference")
rundir <- file.path(working_dir,'run',run_type)
outdir <- file.path(working_dir,'out',run_type)
if(!dir.exists(rundir)) dir.create(rundir,recursive = TRUE)
if(!dir.exists(outdir)) dir.create(outdir,recursive = TRUE)


Mete_path <- "/Volumes/Sd1TB/MODEL_DRIVER/ED2/ICOS/Mete/"
csspss_config_path <- '/Volumes/Sd1TB/MODEL_DRIVER/ED2/ICOS/csspss_config/'
csspss_path <- paste0(csspss_config_path,'site_mean')
pft_xml_path <- paste0(csspss_config_path,'default')
simulating_df <- read.csv(file.path(csspss_config_path,'Site_info_simulating_points.csv'))
css_pss_df <- read.csv(file.path(csspss_config_path,'site_mean_species_pft_new_pft_overview.csv'))

################################################################

list_dir <- list()

for(i in 1:nrow(simulating_df)){
  site_id <- simulating_df$SITE_ID[i]
  yearA <- simulating_df$yearA[i]
  yearM <- simulating_df$inventory_year[i]
  yearZ <- simulating_df$YEARZ[i]
  print(paste(site_id,yearA,yearZ))



  Mete_file_dirs <- list.dirs(Mete_path,full.names = FALSE)
  Mete_prefix = 'FLX_'

  ED2IN_ref <- file.path(ref_dir,"ED2IN_flux_site")
  ed2in <- read_ed2in(ED2IN_ref)

  name_scenar <- paste("simulation",site_id,yearM,yearZ,sep = '_')

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

  ed2in_scenar$IYEARA = yearM
  ed2in_scenar$IYEARZ = yearZ

  # set
  csspss_files = list.files(path = csspss_path,pattern = paste0(site_id,'_',yearM),full.names = TRUE)
  ed2in_scenar$SFILIN = sub("\\.css$", "", csspss_files[1])

  ed2in_scenar$INCLUDE_THESE_PFT = sort(unique(css_pss_df$new_pft[which(css_pss_df$SITE_ID==site_id )]))

  # Change output location
  ed2in_scenar$FFILOUT = file.path(out_scenar,"analy","analysis")
  ed2in_scenar$SFILOUT = file.path(out_scenar,"histo","history")

  # Change config
  ed2in_scenar$IEDCNFGF = file.path(run_scenar,"config.xml")

  write_ed2in.ed2in(ed2in_scenar,filename = file.path(run_scenar,"ED2IN"))

  #######################################################################################
  # Modify config pft_xml_path
  config_file <- list.files(path = pft_xml_path,pattern = paste0(site_id),full.names = TRUE)
  system2("cp",c(config_file, file.path(run_scenar,"config.xml")))

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
  max_parallel = 8
)

# ## 删除之前的模拟结果，确保新的模拟结果不会被之前的结果干扰
# if (dir.exists(rundir)) {
#   unlink(rundir, recursive = TRUE, force = TRUE)
# }
# if (dir.exists(outdir)) {
#   unlink(outdir, recursive = TRUE, force = TRUE)
# }
