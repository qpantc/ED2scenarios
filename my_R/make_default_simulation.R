
source('./my_R/main_added_functions.R')

make_default_simulation_mac <- function(
    i_row,
    css_pss_overview,
    ed2in,
    Mete_file_dirs,
    Mete_prefix,
    Mete_path,
    csspss_file_list,
    csspss_path,
    ref_dir,
    rundir,
    outdir
) {
    site_id <- css_pss_overview$SITE_ID[i_row]
    year_i <- css_pss_overview$time[i_row]

    name_scenar <- paste("simulation",site_id,year_i,sep = '_')

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

    ed2in_scenar$IYEARA = year_i
    ed2in_scenar$IYEARZ = year_i +1


    # set
    ed2in_scenar$SFILIN = paste0(csspss_path,
                            sub("\\.css$", "", csspss_file_list[startsWith(csspss_file_list,paste0(site_id,'_',year_i))][1]))

    # ed2in_scenar$INCLUDE_THESE_PFT = paste0(unique(css_pss_df$pft[which(css_pss_df$SITE_ID==site_id )]),collapse = ',' )

    # Change output location
    ed2in_scenar$FFILOUT = file.path(out_scenar,"analy","analysis")
    ed2in_scenar$SFILOUT = file.path(out_scenar,"histo","history")

    # Change config
    ed2in_scenar$IEDCNFGF = file.path(run_scenar,"config.xml")

    write_ed2in.ed2in(ed2in_scenar,filename = file.path(run_scenar,"ED2IN"))

    #######################################################################################
    # Modify config
    system2("cp",c(file.path(ref_dir,"config_black.xml"),
                    file.path(run_scenar,"config.xml")))

    #######################################################################################
    # Modify job.sh

    write_job_mac(file =  file.path(run_scenar,"job.sh"),
                    # prerun = "ml UDUNITS/2.2.26-intel-2018a R/3.4.4-intel-2018a-X11-20180131 HDF5/1.10.1-intel-2018a; ulimit -s unlimited",
                    prerun = "",
                    CD = run_scenar,
                    ed_exec = "/Users/tiacc/ED2/CODE/ED2/ED/build/ed_2.2-opt-master-2d4e4d44",
                    ED2IN = "ED2IN")

    return(run_scenar)
}

