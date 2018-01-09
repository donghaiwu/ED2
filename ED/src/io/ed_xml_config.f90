!
!! Code for reading XML format config files for ED2
!!
!! Original code by Mike Dietze
!!
!! Main Functions:
!! 
!! read_ed_xml_config(filename,data)
!!    filename = character string
!!    data = ed_data object where parameters are set
!!   Intended to be called by ED_init.f90::EDinit(data) after hardwired defaults are read
!!   in order to set different/site-specific values and/or 
!!   when running batch/optimization/ensemble runs to reset parameters between runs
!!
!! TODO:
!! * write_ed_xml_config(filename,data) -> produce a record of parameters used in a run

subroutine count_pft_xml_config(filename,maxpft)
  integer(4) :: npft,i,myPFT
  integer :: maxpft
  logical(4) :: texist = .false.
  character*(*) :: filename
  character(1),allocatable    ::  readstring(:)
  allocate(readstring(10))
  deallocate(readstring)
print*,'count xml pft : ',trim(filename)
  !! Open File and Init
  call libxml2f90__setformat(1) !set to pure XML but with blank removal
  call libxml2f90__readin_file(trim(filename),'CONFIG')

  call libxml2f90__ll_selectlist('CONFIG')       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','pft',npft)    !get number of pft tags
  print*,"NPFT = ",npft
  maxpft = 0
  if(npft .ge. 1) then
     do i=1,npft
        call libxml2f90__ll_selecttag('DOWN','pft',i) !select pft
        call getConfigINT   ('num','pft',i,myPFT,texist)
        if(texist .and. myPFT > maxpft) maxpft = myPFT
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif

  !! next, check for a MAXPFT flag so don't have to read recursive files
  call libxml2f90__ll_exist('DOWN','maxpft',npft)    !get number of pft tags
  if(npft .ge. 1) then
     do i= 1,npft
        call getConfigINT   ('maxpft','config',i,myPFT,texist)  
        if(texist .and. myPFT > maxpft) maxpft = myPFT
     enddo
  endif

  print*,"MAXPFT = ",maxpft

  return

end subroutine count_pft_xml_config

recursive subroutine read_ed_xml_config(filename)

  use pft_coms
  use hydrology_coms
  use met_driver_coms
  use canopy_radiation_coms
  use disturb_coms
  use phenology_coms
  use physiology_coms
  use decomp_coms
  use fusion_fission_coms
  use grid_coms, only : ngrids
  use ed_max_dims, only : str_len

  use soil_coms  !, only: infiltration_method, dewmax, water_stab_thresh
!  use ed_data
  use ed_misc_coms!, only: ied_init_mode,ffilout,integration_scheme,sfilin,sfilout,thsums_database
  use rk4_coms, only : rk4min_veg_temp
  implicit none
  integer(4) :: i,npft,ntag,myPFT,nlu,myLU,len,ival = 0
  logical(4) :: texist = .false.
  real(8) :: rval
  character*(*) :: filename
  character(len=str_len)  :: cval
  integer             :: ng
!  type(eddata) :: data

  print*,"Opening ED2 XML Config file",trim(filename)

  !! Open File and Init
  call libxml2f90__setformat(1) !set to pure XML but with blank removal
  call libxml2f90__readin_file(trim(filename),trim(filename))!'CONFIG')

  !!********* EXTERN
  !! FIRST, check if any subfiles have to be loaded

  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','extern',ntag)    !get number of pft tags
  print*,"EXTERN READ FROM FILE ::",ntag

  if(ntag .ge. 1) then
     do i=1,ntag
!        call getConfigSTRING  ('extern','config',i,cval,texist)
!print*,cval,texist
        call libxml2f90__ll_selecttag('DOWN','extern',i)
        call libxml2f90__existid('extern',texist)
        if(texist) then 
           call libxml2f90__ll_getsize('extern',len)
           !----- MLO. Changed this to scalar so the interface check will work. -----------!
           call libxml2f90__ll_getch_scal('extern',len,cval)
           cval = cval(1:len)
           print*,"XML recursively loading ",trim(cval)
           call read_ed_xml_config(trim(cval))
        endif
        !! reset to original list
        call libxml2f90__ll_selectlist(TRIM(FILENAME))       
        call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
        call libxml2f90__ll_exist('DOWN','extern',ntag)    !get number of pft tags
     enddo
!!     stop
  endif
  


  !*******  MET PARAMS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','met',ntag)    !get number of met tags
  print*,"MET READ FROM FILE ::",ntag
  if (ntag >= 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','met',i)

        call getConfigREAL  ('met_land_min'   ,'met',i,rval,texist)
        if (texist) met_land_min     = real(rval)
        call getConfigREAL  ('rshort_min'     ,'met',i,rval,texist)
        if (texist) rshort_min       = real(rval)
        call getConfigREAL  ('rshort_max'     ,'met',i,rval,texist)
        if (texist) rshort_max       = real(rval)
        call getConfigREAL  ('rlong_min'      ,'met',i,rval,texist)
        if (texist) rlong_min        = real(rval)
        call getConfigREAL  ('rlong_max'      ,'met',i,rval,texist)
        if (texist) rlong_max        = real(rval)
        call getConfigREAL  ('dt_radinterp'   ,'met',i,rval,texist)
        if (texist) dt_radinterp     = real(rval)
        call getConfigREAL  ('atm_tmp_min'    ,'met',i,rval,texist)
        if (texist) atm_tmp_min      = real(rval)
        call getConfigREAL  ('atm_tmp_max'    ,'met',i,rval,texist)
        if (texist) atm_tmp_max      = real(rval)
        call getConfigREAL  ('atm_shv_min'    ,'met',i,rval,texist)
        if (texist) atm_shv_min      = real(rval)
        call getConfigREAL  ('atm_shv_max'    ,'met',i,rval,texist)
        if (texist) atm_shv_max      = real(rval)
        call getConfigREAL  ('atm_rhv_min'    ,'met',i,rval,texist)
        if (texist) atm_rhv_min      = real(rval)
        call getConfigREAL  ('atm_rhv_max'    ,'met',i,rval,texist)
        if (texist) atm_rhv_max      = real(rval)
        call getConfigREAL  ('atm_co2_min'    ,'met',i,rval,texist)
        if (texist) atm_co2_min      = real(rval)
        call getConfigREAL  ('atm_co2_max'    ,'met',i,rval,texist)
        if (texist) atm_co2_max      = real(rval)
        call getConfigREAL  ('prss_min'       ,'met',i,rval,texist)
        if (texist) prss_min         = real(rval)
        call getConfigREAL  ('prss_max'       ,'met',i,rval,texist)
        if (texist) prss_max         = real(rval)
        call getConfigREAL  ('pcpg_min'       ,'met',i,rval,texist)
        if (texist) pcpg_min         = real(rval)
        call getConfigREAL  ('pcpg_max'       ,'met',i,rval,texist)
        if (texist) pcpg_max         = real(rval)
        call getConfigREAL  ('vels_min'       ,'met',i,rval,texist)
        if (texist) vels_min         = real(rval)
        call getConfigREAL  ('vels_max'       ,'met',i,rval,texist)
        if (texist) vels_max         = real(rval)
        call getConfigREAL  ('geoht_min'      ,'met',i,rval,texist)
        if (texist) geoht_min        = real(rval)
        call getConfigREAL  ('geoht_max'      ,'met',i,rval,texist)
        if (texist) geoht_max        = real(rval)
        call getConfigINT   ('print_radinterp','met',i,ival,texist)
        if (texist) print_radinterp  = ival == 1
        call getConfigSTRING('vbdsf_file'     ,'met',i,cval,texist)
        if (texist) vbdsf_file       = trim(cval)
        call getConfigSTRING('vddsf_file'     ,'met',i,cval,texist)
        if (texist) vddsf_file       = trim(cval)
        call getConfigSTRING('nbdsf_file'     ,'met',i,cval,texist)
        if (texist) nbdsf_file       = trim(cval)
        call getConfigSTRING('nddsf_file'     ,'met',i,cval,texist)
        if (texist) nddsf_file       = trim(cval)
         call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level

      end do
  end if

  !*******  MISC
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','misc',ntag)    !get number of pft tags
  print*,"MISC READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','misc',i)

         call getConfigINT  ('restart_mode','misc',i,ival,texist)
         if(texist) ied_init_mode = ival
         call getConfigSTRING  ('output_filepath','misc',i,cval,texist)
         if(texist) ffilout = trim(cval)
         call getConfigSTRING  ('input_filepath','misc',i,cval,texist)
         if (texist) sfilin = trim(cval)

         call getConfigSTRING  ('history_out_filepath','misc',i,cval,texist)
         if(texist) sfilout = trim(cval)
         call getConfigINT  ('ivegt_dynamics','misc',i,ival,texist)
         if(texist) ivegt_dynamics = ival
         call getConfigINT  ('ibigleaf','misc',i,ival,texist)
         if(texist) ibigleaf = ival
         call getConfigINT  ('integration_scheme','misc',i,ival,texist)
         if(texist) integration_scheme = ival

         call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level

      enddo
  endif


  !*******  ED_MISC
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','ed_misc',ntag)    !get number of pft tags
  print*,"ED_MISC READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','ed_misc',i)
        
        call getConfigINT  ('restart_target_year','ed_misc',i,ival,texist)
        if(texist) then
           restart_target_year = ival
           use_target_year = 1
        endif
        call getConfigINT  ('outputMonth','ed_misc',i,ival,texist)
        ! Output month no longer exists (conflict between branches)
        ! Kept month_yrstep because it does what outputMonth did plus it changes
        ! the month in which patch dynamics occurs.  In case it is set, issue a 
        ! warning.
        if (texist) then
           call warning(" Found ""outputMonth"" was found in XML.  This will overwrite "// &
                        " variable ""month_yrstep"" set in the namelist."                  &
                       ,"read_ed_xml_config","ed_xml_config.f90")
           month_yrstep = ival
        end if
        call getConfigINT  ('burnin','ed_misc',i,ival,texist)
        if(texist) burnin = ival

        !! simple flags to turn on/off edaphic factors
        call getConfigINT  ('vary_elev','ed_misc',i,ival,texist)
        if(texist) vary_elev = ival
        call getConfigINT  ('vary_rad','ed_misc',i,ival,texist)
        if(texist) vary_rad = ival
        call getConfigINT  ('vary_hyd','ed_misc',i,ival,texist)
        if(texist) vary_hyd = ival
        
        
        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
        
      enddo
  endif



  !! read land use data
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','landuse',nlu)    !get number of land use tags
  write(unit=*,fmt='(a,1x,i5)') ' Number of land use types to be read from file =',nlu
  do i=1,nlu
     call libxml2f90__ll_selecttag('DOWN','landuse',i) !select pft
     call getConfigINT   ('num','landuse',i,myLU,texist)
     if (myLU >= 1 .and. myLU <= n_dist_types) then
        call getConfigREAL  ('min_oldgrowth','landuse',i,rval,texist)
        if(texist) min_oldgrowth(myLU) = real(rval)
     else
        write (unit=*,fmt='(a,1x,i6,1x,a)')                                                &
            ' Land use type ',myLU,' is invalid thus ignored!!!'
     end if
     call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
  end do


  !! read PFT data
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','pft',npft)    !get number of pft tags
  print*,"NPFT = ",npft
  print*,"PFT's READ FROM FILE ::",npft
  if (npft >= 1) then
     do i=1,npft
        call libxml2f90__ll_selecttag('DOWN','pft',i) !select pft

        call getConfigINT   ('num','pft',i,myPFT,texist)
        if(myPFT .le. n_pft .and. myPFT .ge. 1) then


!! GENERAL PFT DEFINITION
           call getConfigSTRING('name','pft',i,cval,texist)
           call getConfigINT('is_tropical','pft',i,ival,texist)
           if(texist) then
              if(ival .eq. 0) then
                 is_tropical(myPFT) = .false.
              else
                 is_tropical(myPFT) = .true.
              end if
           end if
           call getConfigINT('is_grass','pft',i,ival,texist)
           if(texist) then
              if(ival .eq. 0) then
                 is_grass(myPFT) = .false.
              else
                 is_grass(myPFT) = .true.
              end if
           end if
           call getConfigINT('is_conifer','pft',i,ival,texist)
           if(texist) then
              if(ival .eq. 0) then
                 is_conifer(myPFT) = .false.
              else
                 is_conifer(myPFT) = .true.
              end if
           end if
           call getConfigINT('is_savannah','pft',i,ival,texist)
           if(texist) then
              if(ival .eq. 0) then
                 is_savannah(myPFT) = .false.
              else
                 is_savannah(myPFT) = .true.
              end if
           end if
           call getConfigINT('is_liana','pft',i,ival,texist)
           if(texist) then
              if(ival .eq. 0) then
                 is_liana(myPFT) = .false.
              else
                 is_liana(myPFT) = .true.
              end if
           end if
           call getConfigINT('include_pft','pft',i,ival,texist)
           if(texist) then
              include_pft(myPFT) = ival == 1
           else
              include_pft(myPFT) = .true.  !! if a PFT is defined, assume it's meant to be included
           endif
           call getConfigINT('include_pft_ag','pft',i,ival,texist)
           if(texist) include_pft_ag(myPFT) = ival == 1
           call getConfigINT('include_pft_fp','pft',i,ival,texist)
           if(texist) include_pft_fp(myPFT) = ival == 1


!! CANOPY RADIATION
	   call getConfigREAL  ('clumping_factor','pft',i,rval,texist)
           if(texist) clumping_factor(myPFT) = real(rval)
	   call getConfigREAL  ('orient_factor','pft',i,rval,texist)
           if(texist) orient_factor(myPFT) = real(rval)

           call getConfigREAL  ('leaf_emiss_tir','pft',i,rval,texist)
           if(texist) leaf_emiss_tir(myPFT) = rval
           call getConfigREAL  ('wood_emiss_tir','pft',i,rval,texist)
           if(texist) wood_emiss_tir(myPFT) = rval

	   call getConfigREAL  ('leaf_reflect_vis','pft',i,rval,texist)
           if(texist) leaf_reflect_vis(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_reflect_nir','pft',i,rval,texist)
           if(texist) leaf_reflect_nir(myPFT) = real(rval)
	   call getConfigREAL  ('wood_reflect_vis','pft',i,rval,texist)
           if(texist) wood_reflect_vis(myPFT) = real(rval)
	   call getConfigREAL  ('wood_reflect_nir','pft',i,rval,texist)
           if(texist) wood_reflect_nir(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_trans_vis','pft',i,rval,texist)
           if(texist) leaf_trans_vis(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_trans_nir','pft',i,rval,texist)
           if(texist) leaf_trans_nir(myPFT) = real(rval)
	   call getConfigREAL  ('wood_trans_vis','pft',i,rval,texist)
           if(texist) wood_trans_vis(myPFT) = real(rval)
	   call getConfigREAL  ('wood_trans_nir','pft',i,rval,texist)
           if(texist) wood_trans_nir(myPFT) = real(rval)

	   call getConfigREAL  ('leaf_backscatter_vis','pft',i,rval,texist)
           if(texist) leaf_backscatter_vis(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_backscatter_nir','pft',i,rval,texist)
           if(texist) leaf_backscatter_nir(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_backscatter_tir','pft',i,rval,texist)
           if(texist) leaf_backscatter_tir(myPFT) = real(rval)
 
	   call getConfigREAL  ('wood_backscatter_vis','pft',i,rval,texist)
           if(texist) wood_backscatter_vis(myPFT) = real(rval)
	   call getConfigREAL  ('wood_backscatter_nir','pft',i,rval,texist)
           if(texist) wood_backscatter_nir(myPFT) = real(rval)
	   call getConfigREAL  ('wood_backscatter_tir','pft',i,rval,texist)
           if(texist) wood_backscatter_vis(myPFT) = real(rval)

	   call getConfigREAL  ('leaf_scatter_vis','pft',i,rval,texist)
           if(texist) leaf_scatter_vis(myPFT) = real(rval)
	   call getConfigREAL  ('leaf_scatter_nir','pft',i,rval,texist)
           if(texist) leaf_scatter_nir(myPFT) = real(rval)
	   call getConfigREAL  ('wood_scatter_vis','pft',i,rval,texist)
           if(texist) wood_scatter_vis(myPFT) = real(rval)
	   call getConfigREAL  ('wood_scatter_nir','pft',i,rval,texist)
           if(texist) wood_scatter_nir(myPFT) = real(rval)

	   call getConfigREAL  ('phi1','pft',i,rval,texist)
           if(texist) phi1(myPFT) = real(rval)
	   call getConfigREAL  ('phi2','pft',i,rval,texist)
           if(texist) phi2(myPFT) = real(rval)
	   call getConfigREAL  ('mu_bar','pft',i,rval,texist)
           if(texist) mu_bar(myPFT) = real(rval)

! photosynthesis variables
           call getConfigINT  ('photosyn_pathway','pft',i,ival,texist)
           if(texist) photosyn_pathway(myPFT) = ival
           call getConfigREAL  ('quantum_efficiency','pft',i,rval,texist)
           if(texist) quantum_efficiency(myPFT) = real(rval)

           call getConfigREAL  ('Vm0','pft',i,rval,texist)
           if(texist) Vm0(myPFT) = real(rval)
           call getConfigREAL  ('Vm_low_temp','pft',i,rval,texist)
           if(texist) Vm_low_temp(myPFT) = real(rval)
           call getConfigREAL  ('Vm_high_temp','pft',i,rval,texist)
           if(texist) Vm_high_temp(myPFT) = real(rval)
	   call getConfigREAL  ('Vm_decay_e','pft',i,rval,texist)
           if(texist) Vm_decay_e(myPFT) = real(rval)
           call getConfigREAL  ('vm_hor','pft',i,rval,texist)
           if(texist) vm_hor(myPFT) = real(rval)
           call getConfigREAL  ('vm_q10','pft',i,rval,texist)
           if(texist) vm_q10(myPFT) = real(rval)

!! Leaf Respiration
           call getConfigREAL  ('dark_respiration_factor','pft',i,rval,texist)
           if(texist) dark_respiration_factor(myPFT) = real(rval)
           call getConfigREAL  ('Rd_low_temp','pft',i,rval,texist)
           if(texist) Rd_low_temp(myPFT) = real(rval)
	   call getConfigREAL  ('Rd_high_temp','pft',i,rval,texist)
           if(texist) Rd_high_temp(myPFT) = real(rval)
	   call getConfigREAL  ('Rd_decay_e','pft',i,rval,texist)
           if(texist) Rd_decay_e(myPFT) = real(rval)
           call getConfigREAL  ('Rd_hor','pft',i,rval,texist)
           if(texist) Rd_hor(myPFT) = real(rval)
           call getConfigREAL  ('Rd_q10','pft',i,rval,texist)
           if(texist) Rd_q10(myPFT) = real(rval)
           call getConfigREAL  ('Rd0','pft',i,rval,texist)
           if(texist) Rd0(myPFT) = real(rval)

!! Stomatal parameters
           call getConfigREAL  ('D0','pft',i,rval,texist)
           if(texist) D0(myPFT) = real(rval)
           call getConfigREAL  ('stomatal_slope','pft',i,rval,texist)
           if(texist) stomatal_slope(myPFT) = real(rval)
           call getConfigREAL  ('cuticular_cond','pft',i,rval,texist)
           if(texist) cuticular_cond(myPFT) = real(rval)
           call getConfigREAL  ('water_conductance','pft',i,rval,texist)
           if(texist) water_conductance(myPFT) = real(rval)
           call getConfigREAL  ('leaf_width','pft',i,rval,texist)
           if(texist) leaf_width(myPFT) = real(rval)
           call getConfigREAL  ('branch_diam','pft',i,rval,texist)
           if(texist) branch_diam(myPFT) = real(rval)

! respiration & turnover variables
           call getConfigREAL  ('growth_resp_factor','pft',i,rval,texist)
           if(texist) growth_resp_factor(myPFT) = real(rval)
           call getConfigREAL  ('leaf_turnover_rate','pft',i,rval,texist)
           if(texist) leaf_turnover_rate(myPFT) = real(rval)
           call getConfigREAL  ('root_turnover_rate','pft',i,rval,texist)
           if(texist) root_turnover_rate(myPFT) = real(rval)
           call getConfigREAL  ('sapw_turnover_rate','pft',i,rval,texist)
           if(texist) sapw_turnover_rate(myPFT) = real(rval)
           call getConfigREAL  ('bark_turnover_rate','pft',i,rval,texist)
           if(texist) bark_turnover_rate(myPFT) = real(rval)
           call getConfigREAL  ('storage_turnover_rate','pft',i,rval,texist)
           if(texist) storage_turnover_rate(myPFT) = real(rval)
           call getConfigREAL  ('f_labile','pft',i,rval,texist)
           if(texist) f_labile_leaf(myPFT) = real(rval)
           call getConfigREAL  ('f_labile_leaf','pft',i,rval,texist)
           if(texist) f_labile_leaf(myPFT) = real(rval)
           call getConfigREAL  ('f_labile_stem','pft',i,rval,texist)
           if(texist) f_labile_stem(myPFT) = real(rval)
           call getConfigREAL  ('root_respiration_factor','pft',i,rval,texist)
           if(texist) root_respiration_factor(myPFT) = real(rval)
           call getConfigREAL  ('rrf_low_temp','pft',i,rval,texist)
           if(texist) rrf_low_temp(myPFT) = real(rval)
           call getConfigREAL  ('rrf_high_temp','pft',i,rval,texist)
           if(texist) rrf_high_temp(myPFT) = real(rval)
           call getConfigREAL  ('rrf_decay_e','pft',i,rval,texist)
           if(texist) rrf_decay_e(myPFT) = real(rval)
           call getConfigREAL  ('rrf_hor','pft',i,rval,texist)
           if(texist) rrf_hor(myPFT) = real(rval)
           call getConfigREAL  ('rrf_q10','pft',i,rval,texist)
           if(texist) rrf_q10(myPFT) = real(rval)

! mortality
           call getConfigREAL  ('frost_mort','pft',i,rval,texist)
           if(texist) frost_mort = real(rval)
           call getConfigREAL  ('mort0','pft',i,rval,texist)
           if(texist) mort0(myPFT) = real(rval)
           call getConfigREAL  ('mort1','pft',i,rval,texist)
           if(texist) mort1(myPFT) = real(rval)
           call getConfigREAL  ('mort2','pft',i,rval,texist)
           if(texist) mort2(myPFT) = real(rval)
           call getConfigREAL  ('mort3','pft',i,rval,texist)
           if(texist) mort3(myPFT) = real(rval)
           call getConfigREAL  ('cbr_severe_stress','pft',i,rval,texist)
           if(texist) cbr_severe_stress(myPFT) = real(rval)
           call getConfigREAL  ('seedling_mortality','pft',i,rval,texist)
           if(texist) seedling_mortality(myPFT) = real(rval)
	   
	   call getConfigREAL  ('treefall_gt','pft',i,rval,texist)
           if(texist) treefall_s_gtht(myPFT) = real(rval)
           call getConfigREAL  ('treefall_s_gtht','pft',i,rval,texist)
           if(texist) treefall_s_gtht(myPFT) = real(rval)
           call getConfigREAL  ('treefall_lt','pft',i,rval,texist)
           if(texist) treefall_s_ltht(myPFT) = real(rval)
           call getConfigREAL  ('treefall_s_ltht','pft',i,rval,texist)
           if(texist) treefall_s_ltht(myPFT) = real(rval)
           call getConfigREAL  ('felling_s_gtharv','pft',i,rval,texist)
           if(texist) felling_s_gtharv(myPFT) = real(rval)
           call getConfigREAL  ('felling_s_ltharv','pft',i,rval,texist)
           if(texist) felling_s_ltharv(myPFT) = real(rval)
           call getConfigREAL  ('skid_s_gtharv','pft',i,rval,texist)
           if(texist) skid_s_gtharv(myPFT) = real(rval)
           call getConfigREAL  ('skid_s_ltharv','pft',i,rval,texist)
           if(texist) skid_s_ltharv(myPFT) = real(rval)
           call getConfigREAL  ('fire_s_min','pft',i,rval,texist)
           if(texist) fire_s_min(myPFT) = real(rval)
           call getConfigREAL  ('fire_s_max','pft',i,rval,texist)
           if(texist) fire_s_max(myPFT) = real(rval)
           call getConfigREAL  ('fire_s_inter','pft',i,rval,texist)
           if(texist) fire_s_inter(myPFT) = real(rval)
           call getConfigREAL  ('fire_s_slope','pft',i,rval,texist)
           if(texist) fire_s_slope(myPFT) = real(rval)

           call getConfigREAL  ('plant_min_temp','pft',i,rval,texist)
           if(texist) plant_min_temp(myPFT) = real(rval)	   

! allocation variables
           call getConfigREAL  ('rho','pft',i,rval,texist)
           if(texist) rho(myPFT) = real(rval)
           call getConfigREAL  ('SLA','pft',i,rval,texist)
           if(texist) SLA(myPFT) = real(rval)
           call getConfigREAL  ('q','pft',i,rval,texist)
           if(texist) q(myPFT) = real(rval)
           call getConfigREAL  ('sapwood_ratio','pft',i,rval,texist)
           if(texist) sapwood_ratio(myPFT) = real(rval)
           call getConfigREAL  ('qsw','pft',i,rval,texist)
           if(texist) qsw(myPFT) = real(rval)
           call getConfigREAL  ('qbark','pft',i,rval,texist)
           if(texist) qbark(myPFT) = real(rval)
           call getConfigREAL  ('init_density','pft',i,rval,texist)
           if(texist) init_density(myPFT) = real(rval)
           call getConfigREAL  ('f_bstorage_init','pft',i,rval,texist)
           if(texist) f_bstorage_init(myPFT) = real(rval)

     ! Height
           call getConfigREAL  ('b1Ht','pft',i,rval,texist)
           if(texist) b1Ht(myPFT) = real(rval)
           call getConfigREAL  ('b2Ht','pft',i,rval,texist)
           if(texist) b2Ht(myPFT) = real(rval)
	   call getConfigREAL  ('hgt_ref','pft',i,rval,texist)
           if(texist) hgt_ref(myPFT) = real(rval)
           call getConfigREAL  ('hgt_min','pft',i,rval,texist)
           if(texist) hgt_min(myPFT) = real(rval)
           call getConfigREAL  ('hgt_max','pft',i,rval,texist)
           if(texist) hgt_max(myPFT) = real(rval)
	   call getConfigREAL  ('min_dbh','pft',i,rval,texist)
           if(texist) min_dbh(myPFT) = real(rval)
           call getConfigREAL  ('dbh_crit','pft',i,rval,texist)
           if(texist) dbh_crit(myPFT) = real(rval)
           call getConfigREAL  ('dbh_bigleaf','pft',i,rval,texist)
           if(texist) dbh_bigleaf(myPFT) = real(rval)

     ! Leaf
           call getConfigREAL  ('b1Bl','pft',i,rval,texist)
           if (texist) then
              b1Bl_small(myPFT) = real(rval)
              b1Bl_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b2Bl','pft',i,rval,texist)
           if (texist) then
              b2Bl_small(myPFT) = real(rval)
              b2Bl_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b1Bl_small','pft',i,rval,texist)
           if (texist) b1Bl_small(myPFT) = real(rval)
           call getConfigREAL  ('b2Bl_small','pft',i,rval,texist)
           if (texist) b2Bl_small(myPFT) = real(rval)
           call getConfigREAL  ('b1Bl_large','pft',i,rval,texist)
           if (texist) b1Bl_large(myPFT) = real(rval)
           call getConfigREAL  ('b2Bl_large','pft',i,rval,texist)
           if (texist) b2Bl_large(myPFT) = real(rval)

     ! Stem
           call getConfigREAL  ('b1Bs','pft',i,rval,texist)
           if (texist) then
              b1Bs_small(myPFT) = real(rval)
              b1Bs_large(myPFT)   = real(rval)
           end if
           call getConfigREAL  ('b2Bs','pft',i,rval,texist)
           if (texist) then
              b2Bs_small(myPFT) = real(rval)
              b2Bs_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b1Bs_small','pft',i,rval,texist)
           if (texist) then
              b1Bs_small(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b2Bs_small','pft',i,rval,texist)
           if (texist) then
              b2Bs_small(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b1Bs_large','pft',i,rval,texist)
           if (texist) then
              b1Bs_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b2Bs_large','pft',i,rval,texist)
           if (texist) then
              b2Bs_large(myPFT) = real(rval)
           end if
	   call getConfigREAL  ('min_bdead','pft',i,rval,texist)
           if(texist) min_bdead(myPFT) = real(rval)
	   call getConfigREAL  ('bdead_crit','pft',i,rval,texist)
           if(texist) bdead_crit(myPFT) = real(rval)

     ! Canopy
	   call getConfigREAL  ('b1Ca','pft',i,rval,texist)
           if(texist) b1Ca(myPFT) = real(rval)
	   call getConfigREAL  ('b2Ca','pft',i,rval,texist)
           if(texist) b2Ca(myPFT) = real(rval)

     ! branches
           call getConfigREAL  ('b1WAI','pft',i,rval,texist)
           if (texist) then
              b1WAI_small(myPFT) = real(rval)
              b1WAI_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b2WAI','pft',i,rval,texist)
           if (texist) then
              b2WAI_small(myPFT) = real(rval)
              b2WAI_large(myPFT) = real(rval)
           end if
           call getConfigREAL  ('b1WAI_small','pft',i,rval,texist)
           if (texist) b1WAI_small(myPFT) = real(rval)
           call getConfigREAL  ('b2WAI_small','pft',i,rval,texist)
           if (texist) b2WAI_small(myPFT) = real(rval)
           call getConfigREAL  ('b1WAI_large','pft',i,rval,texist)
           if (texist) b1WAI_large(myPFT) = real(rval)
           call getConfigREAL  ('b2WAI_large','pft',i,rval,texist)
           if (texist) b2WAI_large(myPFT) = real(rval)
           call getConfigREAL  ('brf_wd','pft',i,rval,texist)
           if(texist) brf_wd(myPFT) = real(rval)

     ! bark/sapwood thickness
	   call getConfigREAL  ('qrhob','pft',i,rval,texist)
           if(texist) qrhob(myPFT) = real(rval)
	   call getConfigREAL  ('b1Xb','pft',i,rval,texist)
           if(texist) b1Xb(myPFT) = real(rval)
	   call getConfigREAL  ('b1Xs','pft',i,rval,texist)
           if(texist) b1Xs(myPFT) = real(rval)

    ! coarse roots
           call getConfigREAL  ('agf_bs','pft',i,rval,texist)
           if(texist) agf_bs(:) = real(rval)
	   call getConfigREAL  ('b1Vol','pft',i,rval,texist)
           if(texist) b1Vol(myPFT) = real(rval)
	   call getConfigREAL  ('b2Vol','pft',i,rval,texist)
           if(texist) b2Vol(myPFT) = real(rval)
	   call getConfigREAL  ('b1Rd','pft',i,rval,texist)
           if(texist) b1Rd(myPFT) = real(rval)
	   call getConfigREAL  ('b2Rd','pft',i,rval,texist)
           if(texist) b2Rd(myPFT) = real(rval)

	   call getConfigREAL  ('init_laimax','pft',i,rval,texist)
           if(texist) init_laimax(myPFT) = real(rval)

! nitro
           call getConfigREAL  ('c2n_leaf','pft',i,rval,texist)
           if(texist) c2n_leaf(myPFT) = real(rval)
!           call getConfigREAL  ('c2n_stem','pft',i,rval,texist)                  !! not pft-level in current mainline
!           if(texist) c2n_stem(myPFT) = real(rval)
!!$           call getConfigREAL  ('c2n_storage','pft',i,rval,texist)
!!$           if(texist) c2n_storage(myPFT) = real(rval)

! leaf dependent
           call getConfigINT   ('phenology','pft',i,ival,texist)
           if(texist) phenology(myPFT) = ival

! Specific heat
           call getConfigREAL  ('c_grn_leaf_dry','pft',i,rval,texist)
           if(texist) c_grn_leaf_dry(myPFT) = real(rval)
           call getConfigREAL  ('c_ngrn_wood_dry','pft',i,rval,texist)
           if(texist) c_ngrn_wood_dry(myPFT) = real(rval)
           call getConfigREAL  ('c_ngrn_bark_dry','pft',i,rval,texist)
           if(texist) c_ngrn_bark_dry(myPFT) = real(rval)
           call getConfigREAL  ('wat_dry_ratio_leaf','pft',i,rval,texist)
           if(texist) wat_dry_ratio_leaf(myPFT) = real(rval)
           call getConfigREAL  ('wat_dry_ratio_wood','pft',i,rval,texist)
           if(texist) wat_dry_ratio_wood(myPFT) = real(rval)
           call getConfigREAL  ('wat_dry_ratio_bark','pft',i,rval,texist)
           if(texist) wat_dry_ratio_bark(myPFT) = real(rval)
           call getConfigREAL  ('delta_c_wood','pft',i,rval,texist)
           if(texist) delta_c_wood(myPFT) = real(rval)
           call getConfigREAL  ('delta_c_bark','pft',i,rval,texist)
           if(texist) delta_c_bark(myPFT) = real(rval)

! Crown depth
           call getConfigREAL  ('b1Cl','pft',i,rval,texist)
           if(texist) b1Cl(myPFT) = real(rval)
           call getConfigREAL  ('b2Cl','pft',i,rval,texist)
           if(texist) b2Cl(myPFT) = real(rval)

! reproduction
           call getConfigREAL  ('r_fract','pft',i,rval,texist)
           if(texist) r_fract(myPFT) = real(rval)
!!$           call getConfigREAL  ('c_fract','pft',i,rval,texist)
!!$           if(texist) c_fract(myPFT) = real(rval)
           call getConfigREAL  ('st_fract','pft',i,rval,texist)
           if(texist) st_fract(myPFT) = real(rval)
           call getConfigREAL  ('nonlocal_dispersal','pft',i,rval,texist)
           if(texist) nonlocal_dispersal(myPFT) = real(rval)
           call getConfigREAL  ('repro_min_h','pft',i,rval,texist)
           if(texist) repro_min_h(myPFT) = real(rval)

!!! OTHER / derived
           call getConfigREAL  ('seed_rain','pft',i,rval,texist)
           if(texist) seed_rain(myPFT) = real(rval)

        else
           print*,"INVALID PFT READ FROM CONFIG FILE ::", myPFT
        endif
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif

  !********* READ PFT CONSTANTS (PFTCONST) PARMS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','pftconst',ntag)    !get number of pft tags
  print*,"PFTCONST READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','pftconst',i)
        
        call getConfigREAL  ('c2n_slow','pftconst',i,rval,texist)
        if(texist) c2n_slow = real(rval)
        call getConfigREAL  ('c2n_structural','pftconst',i,rval,texist)
        if(texist) c2n_structural = real(rval)
!        call getConfigREAL  ('c2n_stem','pftconst',i,rval,texist)
!        if(texist) c2n_stem = real(rval)
        call getConfigREAL  ('l2n_stem','pftconst',i,rval,texist)
        if(texist) l2n_stem = real(rval)
        call getConfigREAL  ('C2B','pftconst',i,rval,texist)
        if(texist) C2B = real(rval)


     ! liana-specific parameters
        call getConfigREAL  ('h_edge','pftconst',i,rval,texist)
        if(texist) h_edge = real(rval)
        call getConfigREAL  ('liana_dbh_crit','pftconst',i,rval,texist)
        if(texist) liana_dbh_crit = real(rval)

        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
  

  !********* READ HYDROLOGY PARMS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','hydro',ntag)    !get number of pft tags
  print*,"HYDROLOGY READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','hydro',i)

         call getConfigINT  ('useTOPMODEL','hydro',i,ival,texist)
         if(texist) useTOPMODEL = ival
         call getConfigINT  ('useRUNOFF','hydro',i,ival,texist)
         if(texist) useRUNOFF = ival
         call getConfigINT  ('outputPeriod','hydro',i,ival,texist)
         if(texist) HydroOutputPeriod = ival
         call getConfigREAL  ('MoistRateTuning','hydro',i,rval,texist)
         if(texist) MoistRateTuning = real(rval)
         call getConfigREAL  ('MoistSatThresh','hydro',i,rval,texist)
         if(texist) MoistSatThresh = real(rval)
         call getConfigREAL  ('MoistdWT','hydro',i,rval,texist)
         if(texist) Moist_dWT = real(rval)
         call getConfigREAL  ('FracLiqRunoff','hydro',i,rval,texist)
         if(texist) FracLiqRunoff = real(rval)
         call getConfigREAL  ('runoff_vmax','hydro',i,rval,texist)
         if(texist) runoff_vmax = real(rval)
         call getConfigREAL  ('GrassLAImax','hydro',i,rval,texist)
         if(texist) GrassLAImax = real(rval)
!! redundant with SOIL runoff_time 
         call getConfigREAL  ('inverse_runoff_time','hydro',i,rval,texist)
         if(texist) then
            print*,"hydro::inverse_runoff_time was found to be redundant with soil::runoff_time"
            print*,"Please update your xml config file"
            stop
         endif
 
         call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level

      enddo
  endif

  !********* READ CLIMATE SCENARIO PARMS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','scenario',ntag)    !get number of pft tags
  print*,"SCENARIO READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','scenario',i)
        
        call getConfigREAL  ('atm_tmp_intercept','scenario',i,rval,texist)
        if(texist) atm_tmp_intercept = real(rval)
        call getConfigREAL  ('atm_tmp_slope','scenario',i,rval,texist)
        if(texist) atm_tmp_slope = real(rval)
        call getConfigREAL  ('prec_intercept','scenario',i,rval,texist)
        if(texist) prec_intercept = real(rval)
        call getConfigREAL  ('prec_slope','scenario',i,rval,texist)
        if(texist) prec_slope = real(rval)
        call getConfigINT  ('humid_scenario','scenario',i,ival,texist)
        if(texist)  humid_scenario = ival
        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
   

  !********* READ LAPSE PARMS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','lapse',ntag)    !get number of pft tags
  print*,"LAPSE READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        call libxml2f90__ll_selecttag('DOWN','lapse',i)

         call getConfigREAL  ('geoht','lapse',i,rval,texist)
         if(texist) lapse%geoht = real(rval)
         call getConfigREAL  ('vels','lapse',i,rval,texist)
         if(texist) lapse%vels = real(rval)
         call getConfigREAL  ('atm_ustar','lapse',i,rval,texist)
         if(texist) lapse%atm_ustar = real(rval)
         call getConfigREAL  ('atm_tmp','lapse',i,rval,texist)
         if(texist) lapse%atm_tmp = real(rval)
         call getConfigREAL  ('rv','lapse',i,rval,texist)
         if(texist) lapse%atm_shv = real(rval)
         call getConfigREAL  ('prss','lapse',i,rval,texist)
         if(texist) lapse%prss = real(rval)
         call getConfigREAL  ('pcpg','lapse',i,rval,texist)
         if(texist) lapse%pcpg = real(rval)
         call getConfigREAL  ('atm_co2','lapse',i,rval,texist)
         if(texist) lapse%atm_co2 = real(rval)
         call getConfigREAL  ('rlong','lapse',i,rval,texist)
         if(texist) lapse%rlong = real(rval)
         call getConfigREAL  ('par_diffuse','lapse',i,rval,texist)
         if(texist) lapse%par_diffuse = real(rval)
         call getConfigREAL  ('par_beam','lapse',i,rval,texist)
         if(texist) lapse%par_beam = real(rval)
         call getConfigREAL  ('nir_diffuse','lapse',i,rval,texist)
         if(texist) lapse%nir_diffuse = real(rval)
         call getConfigREAL  ('nir_beam','lapse',i,rval,texist)
         if(texist) lapse%nir_beam = real(rval)
         call getConfigREAL  ('pptnorm','lapse',i,rval,texist)
         if(texist) lapse%pptnorm = real(rval)


         call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
      enddo
  endif

  !********  CANOPY_RADIATION
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','radiation',ntag)    !get number of pft tags
  print*,"CANOPY RADIATION READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag

        call libxml2f90__ll_selecttag('DOWN','radiation',i)
        
        call getConfigREAL  ('rlong_min','radiation',i,rval,texist)
        if(texist) rlong_min = real(rval) 
        call getConfigREAL  ('veg_temp_min','radiation',i,rval,texist)
        if(texist) rk4min_veg_temp = rval ! This is double precision. 
!        call getConfigREAL  ('visible_fraction','radiation',i,rval,texist)
!        if(texist) visible_fraction = real(rval)
!        call getConfigREAL  ('visible_fraction_dir','radiation',i,rval,texist)
!        if(texist) visible_fraction_dir = real(rval)
!        call getConfigREAL  ('visible_fraction_dif','radiation',i,rval,texist)
!        if(texist) visible_fraction_dif = real(rval)
        call getConfigREAL  ('leaf_scatter_nir','radiation',i,rval,texist)
        if(texist) leaf_scatter_nir = real(rval)
        call getConfigREAL  ('leaf_reflect_nir','radiation',i,rval,texist)
        if(texist) leaf_reflect_nir = real(rval)
        call getConfigREAL  ('leaf_trans_nir','radiation',i,rval,texist)
        if(texist) leaf_trans_nir = real(rval)
        call getConfigREAL  ('diffuse_backscatter_vis','radiation',i,rval,texist)
        if(texist) leaf_backscatter_vis = real(rval)
        call getConfigREAL  ('diffuse_backscatter_nir','radiation',i,rval,texist)
        if(texist) leaf_backscatter_nir = real(rval)

        !----- Crown closure index variables. ---------------------------------------------!
        call getConfigREAL  ('cci_radius','radiation',i,rval,texist)
        if(texist) cci_radius  = real(rval)
        call getConfigREAL  ('cci_pixres','radiation',i,rval,texist)
        if(texist) cci_pixres  = real(rval)
        call getConfigREAL  ('cci_gapsize','radiation',i,rval,texist)
        if(texist) cci_gapsize = real(rval)
        call getConfigREAL  ('cci_gapmin','radiation',i,rval,texist)
        if(texist) cci_gapmin  = real(rval)
        call getConfigINT  ('cci_nretn','radiation',i,ival,texist)
        if(texist) cci_nretn = ival
        !----------------------------------------------------------------------------------!

        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif


  !********* SOILS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','soil',ntag)    !get number of pft tags
  print*,"SOIL READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag

        call libxml2f90__ll_selecttag('DOWN','soil',i)
        
        call getConfigREAL  ('water_stab_thresh','soil',i,rval,texist)
        if(texist) water_stab_thresh = real(rval)
        call getConfigINT  ('infiltration_method','soil',i,ival,texist)
         if(texist) infiltration_method = ival
         call getConfigREAL  ('dewmax','soil',i,rval,texist)
         if(texist) dewmax = real(rval)

         call getConfigSTRING  ('vegetation_database','soil',i,cval,texist)
         if (texist) then
            do ng=1,ngrids
               veg_database(ng) = trim(cval)
            end do
         end if

         call getConfigSTRING  ('soil_database','soil',i,cval,texist)
         if (texist) then
            do ng=1,ngrids
               soil_database(ng) = trim(cval)
            end do
         end if

         call getConfigSTRING  ('soilstate_db','soil',i,cval,texist)
         if (texist) soilstate_db = trim(cval)

         call getConfigSTRING  ('soildepth_db','soil',i,cval,texist)
         if (texist) soildepth_db = trim(cval)

         call getConfigINT  ('isoilstateinit','soil',i,ival,texist)
         if(texist) isoilstateinit = ival
         call getConfigINT  ('isoildepthflg','soil',i,ival,texist)
         if(texist) isoildepthflg = ival

         !!CHECK FOR CONFLICT WITH INVERSE_RUNOFF_TIME
         call getConfigREAL  ('runoff_time','soil',i,rval,texist) 
         if(texist) runoff_time = real(rval)
      
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
  


  !********* DECOMPOSITION
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','decomposition',ntag)    !get number of pft tags
  print*,"DECOMPOSITION READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        
        call libxml2f90__ll_selecttag('DOWN','decomposition',i)
        
        call getConfigREAL  ('cwd_frac','decomposition',i,rval,texist)
        if(texist) cwd_frac = real(rval)

        call getConfigREAL  ('resp_opt_water','decomposition',i,rval,texist)
        if(texist)  resp_opt_water = real(rval)
        call getConfigREAL  ('resp_water_below_opt','decomposition',i,rval,texist)
        if(texist) resp_water_below_opt = real(rval)
        call getConfigREAL  ('resp_water_above_opt','decomposition',i,rval,texist)
        if(texist) resp_water_above_opt = real(rval)
        call getConfigREAL  ('resp_temperature_increase','decomposition',i,rval,texist)
        if(texist) resp_temperature_increase = real(rval)
        call getConfigREAL  ('N_immobil_supply_scale','decomposition',i,rval,texist)
        if(texist) N_immobil_supply_scale = real(rval)
        call getConfigREAL  ('r_fsc','decomposition',i,rval,texist)
        if(texist)  r_fsc = real(rval)
        call getConfigREAL  ('r_stsc','decomposition',i,rval,texist)
        if(texist)  r_stsc = real(rval)
        call getConfigREAL  ('r_ssc','decomposition',i,rval,texist)
        if(texist)  r_ssc = real(rval)
        call getConfigREAL  ('K1','decomposition',i,rval,texist)
        if(texist)  decay_rate_stsc = real(rval)
        call getConfigREAL  ('K2','decomposition',i,rval,texist)
        if(texist)  decay_rate_fsc = real(rval)
        call getConfigREAL  ('K3','decomposition',i,rval,texist)
        if(texist)  decay_rate_ssc = real(rval)
        call getConfigREAL  ('decay_rate_stsc','decomposition',i,rval,texist)
        if(texist)  decay_rate_stsc = real(rval)
        call getConfigREAL  ('decay_rate_fsc','decomposition',i,rval,texist)
        if(texist)  decay_rate_fsc = real(rval)
        call getConfigREAL  ('decay_rate_ssc','decomposition',i,rval,texist)
        if(texist)  decay_rate_ssc = real(rval)
        call getConfigINT   ('N_decomp_lim','decomposition',i,ival,texist)
        if(texist)  N_decomp_lim= ival
        call getConfigREAL  ('rh_decay_low','decomposition',i,rval,texist)
        if(texist)  rh_decay_low = real(rval)
        call getConfigREAL  ('rh_decay_high','decomposition',i,rval,texist)
        if(texist)  rh_decay_high = real(rval)
        call getConfigREAL  ('rh_low_temp','decomposition',i,rval,texist)
        if(texist)  rh_low_temp = real(rval)
        call getConfigREAL  ('rh_high_temp','decomposition',i,rval,texist)
        if(texist)  rh_high_temp = real(rval)
        call getConfigREAL  ('rh_decay_dry','decomposition',i,rval,texist)
        if(texist)  rh_decay_dry = real(rval)
        call getConfigREAL  ('rh_decay_wet','decomposition',i,rval,texist)
        if(texist)  rh_decay_wet = real(rval)
        call getConfigREAL  ('rh_dry_smoist','decomposition',i,rval,texist)
        if(texist)  rh_dry_smoist = real(rval)
        call getConfigREAL  ('rh_wet_smoist','decomposition',i,rval,texist)
        if(texist)  rh_wet_smoist = real(rval)

        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif


  !******** FUSION/FISSION
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','fusefiss',ntag)    !get number of pft tags
  print*,"FUSEFISS READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        
        call libxml2f90__ll_selecttag('DOWN','fusefiss',i)
        
        call getConfigREAL  ('min_recruit_size','fusefiss',i,rval,texist)
        if(texist) min_recruit_size = real(rval)

        call getConfigINT  ('ff_nhgt','fusefiss',i,ival,texist)
        if(texist) ff_nhgt = ival

        !! Old patch and cohort fusion parameters (slated to be deleted)
        call getConfigREAL  ('dark_cumlai_min','fusefiss',i,rval,texist)
        if(texist) dark_cumlai_min = real(rval)
        call getConfigREAL  ('dark_cumlai_max','fusefiss',i,rval,texist)
        if(texist) dark_cumlai_max = real(rval)
        call getConfigREAL  ('sunny_cumlai_min','fusefiss',i,rval,texist)
        if(texist) sunny_cumlai_min = real(rval)
        call getConfigREAL  ('sunny_cumlai_max','fusefiss',i,rval,texist)
        if(texist) sunny_cumlai_max = real(rval)
        call getConfigREAL  ('light_toler_min','fusefiss',i,rval,texist)
        if(texist) light_toler_min = real(rval)
        call getConfigREAL  ('light_toler_max','fusefiss',i,rval,texist)
        if(texist) light_toler_max = real(rval)
        call getConfigREAL  ('dark_cumlai_mult','fusefiss',i,rval,texist)
        if(texist) dark_cumlai_mult = real(rval)
        call getConfigREAL  ('sunny_cumlai_mult','fusefiss',i,rval,texist)
        if(texist) sunny_cumlai_mult = real(rval)
        call getConfigREAL  ('light_toler_mult','fusefiss',i,rval,texist)
        if(texist) light_toler_mult = real(rval)
        call getConfigREAL  ('fusetol','fusefiss',i,rval,texist)
        if(texist) fusetol = real(rval)
        call getConfigREAL  ('fusetol_h','fusefiss',i,rval,texist)
        if(texist) fusetol_h = real(rval)
        call getConfigREAL  ('lai_fuse_tol','fusefiss',i,rval,texist)
        if(texist) lai_fuse_tol = real(rval)
        call getConfigREAL  ('coh_tolerance_max','fusefiss',i,rval,texist)
        if(texist) coh_tolerance_max = real(rval)
        call getConfigINT  ('fuse_relax','fusefiss',i,ival,texist)
        if(texist) fuse_relax = ival == 1

        !!! New/remaining patch and cohort fusion parameters
        call getConfigINT  ('niter_patfus','fusefiss',i,ival,texist)
        if(texist) niter_patfus = ival
        call getConfigREAL  ('pat_light_ext','fusefiss',i,rval,texist)
        if(texist) pat_light_ext = real(rval)
        call getConfigREAL  ('pat_light_tol_min','fusefiss',i,rval,texist)
        if(texist) pat_light_tol_min = real(rval)
        call getConfigREAL  ('pat_light_tol_max','fusefiss',i,rval,texist)
        if(texist) pat_light_tol_max = real(rval)
        call getConfigREAL  ('pat_light_tol_mult','fusefiss',i,rval,texist)
        if(texist) pat_light_tol_mult = real(rval)
        call getConfigREAL  ('pat_light_mxd_fac','fusefiss',i,rval,texist)
        if(texist) pat_light_mxd_fac = real(rval)
        call getConfigREAL  ('pat_diff_age_tol','fusefiss',i,rval,texist)
        if(texist) pat_diff_age_tol = real(rval)
        call getConfigREAL  ('pat_min_area_remain','fusefiss',i,rval,texist)
        if(texist) pat_min_area_remain = real(rval)
        call getConfigREAL  ('coh_size_tol_min','fusefiss',i,rval,texist)
        if(texist) coh_size_tol_min = real(rval)
        call getConfigREAL  ('coh_size_tol_max','fusefiss',i,rval,texist)
        if(texist) coh_size_tol_max = real(rval)
        call getConfigREAL  ('coh_size_tol_mult','fusefiss',i,rval,texist)
        if(texist) coh_size_tol_mult = real(rval)

        call getConfigREAL  ('lai_tol','fusefiss',i,rval,texist)
        if(texist) lai_tol = real(rval)
!        call getConfigREAL  ('ntol','fusefiss',i,rval,texist)
        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
    
  !*********  Horizontal shading
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','hrzshade',ntag)    !get number of hrzshade tags
  print*,"HORIZONTAL SHADING READ FROM FILE ::",ntag
  if (ntag >= 1) then
     do i=1,ntag

        call libxml2f90__ll_selecttag('DOWN','hrzshade',i)

        call getConfigREAL  ('cci_radius','hrzshade',i,rval,texist)
        if(texist) cci_radius = real(rval)
        call getConfigREAL  ('cci_pixres','hrzshade',i,rval,texist)
        if(texist) cci_pixres = real(rval)
        call getConfigREAL  ('cci_gapsize','hrzshade',i,rval,texist)
        if(texist) cci_gapsize = real(rval)
        call getConfigREAL  ('cci_gapmin','hrzshade',i,rval,texist)
        if(texist) cci_gapmin = real(rval)
        call getConfigINT  ('cci_nretn','hrzshade',i,ival,texist)
        if(texist) cci_nretn = ival
        call getConfigREAL  ('cci_hmax','hrzshade',i,rval,texist)
        if(texist) cci_hmax = real(rval)


        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     end do
  end if


  !*********  DISTURBANCE
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','disturbance',ntag)    !get number of pft tags
  print*,"DISTURBANCE READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag

        call libxml2f90__ll_selecttag('DOWN','disturbance',i)
        
        !! GENERAL
        call getConfigREAL  ('min_new_patch_area','disturbance',i,rval,texist)
        if(texist) min_patch_area = real(rval)
        !! GENERAL
        call getConfigREAL  ('min_patch_area','disturbance',i,rval,texist)
        if(texist) min_patch_area = real(rval)
        call getConfigINT  ('include_fire','disturbance',i,ival,texist)
        if(texist) include_fire = ival
        call getConfigINT  ('ianth_disturb','disturbance',i,ival,texist)
        if(texist) ianth_disturb = ival
 
        !! TREEFALL
        call getConfigREAL  ('treefall_disturbance_rate','disturbance',i,rval,texist)
        if(texist) treefall_disturbance_rate = real(rval)
        
        call getConfigREAL  ('Time2Canopy','disturbance',i,rval,texist)
        if(texist) Time2Canopy = real(rval)
        
        call getConfigREAL  ('treefall_hite_threshold','disturbance',i,rval,texist)
        if(texist) treefall_hite_threshold = real(rval)

        !! FORESTRY
        call getConfigINT  ('plantation_year','disturbance',i,ival,texist)
        if(texist) plantation_year = ival
        call getConfigREAL  ('plantation_rotation','disturbance',i,rval,texist)
        if(texist) plantation_rotation = real(rval)
        call getConfigREAL  ('min_harvest_biomass','disturbance',i,rval,texist)
        if(texist) min_harvest_biomass = real(rval)
        call getConfigREAL  ('mature_harvest_age','disturbance',i,rval,texist)
        if(texist) mature_harvest_age = real(rval)
        !! Possibly DEPRECATED 
        call getConfigINT  ('forestry_on','disturbance',i,ival,texist)
        if(texist) forestry_on = ival
        call getConfigINT  ('agriculture_on','disturbance',i,ival,texist)
        if(texist) agriculture_on = ival
        
        !! FIRE
        call getConfigREAL  ('fire_dryness_threshold','disturbance',i,rval,texist)
        if(texist) fire_dryness_threshold = real(rval)
        call getConfigREAL  ('fire_parameter','disturbance',i,rval,texist)
        if(texist) fire_parameter = real(rval)
        call getConfigREAL  ('fire_smoist_depth','disturbance',i,rval,texist)
        if(texist) fire_smoist_depth = real(rval)
        call getConfigREAL  ('fuel_height_max','disturbance',i,rval,texist)
        if(texist) fuel_height_max = real(rval)
        call getConfigREAL  ('f_combusted_fast','disturbance',i,rval,texist)
        if(texist) f_combusted_fast = real(rval)
        call getConfigREAL  ('f_combusted_struct','disturbance',i,rval,texist)
        if(texist) f_combusted_struct = real(rval)
        call getConfigREAL  ('agf_fsc','disturbance',i,rval,texist)
        if(texist) agf_fsc = real(rval)
        call getConfigREAL  ('agf_stsc','disturbance',i,rval,texist)
        if(texist) agf_stsc = real(rval)

        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
  

  !********** PHENOLOGY
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','phenology',ntag)    !get number of pft tags
  print*,"PHENOLOGY READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        
        call libxml2f90__ll_selecttag('DOWN','phenology',i)
        
        call getConfigREAL  ('retained_carbon_fraction','phenology',i,rval,texist)
        if(texist)  retained_carbon_fraction = real(rval)
        call getConfigREAL  ('theta_crit','phenology',i,rval,texist)
        if(texist)  thetacrit= real(rval)
        call getConfigREAL  ('dl_tr','phenology',i,rval,texist)
        if(texist)  dl_tr = real(rval)
        call getConfigREAL  ('st_tr1','phenology',i,rval,texist)
        if(texist)  st_tr1 = real(rval)
        call getConfigREAL  ('st_tr2','phenology',i,rval,texist)
        if(texist)  st_tr2 = real(rval)
        call getConfigREAL  ('phen_a','phenology',i,rval,texist)
        if(texist)  phen_a = real(rval)
        call getConfigREAL  ('phen_b','phenology',i,rval,texist)
        if(texist)  phen_b = real(rval)
        call getConfigREAL  ('phen_c','phenology',i,rval,texist)
        if(texist)  phen_c = real(rval)
        call getConfigINT  ('iphen_scheme','phenology',i,ival,texist)
        if(texist) iphen_scheme = ival

        call getConfigINT  ('iphenys1','phenology',i,ival,texist)
        if(texist) iphenys1 = ival
        call getConfigINT  ('iphenysf','phenology',i,ival,texist)
        if(texist) iphenysf = ival
        call getConfigINT  ('iphenyf1','phenology',i,ival,texist)
        if(texist) iphenyf1 = ival
        call getConfigINT  ('iphenyff','phenology',i,ival,texist)
        if(texist) iphenyff = ival

        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif


  !********** PHYSIOLOGY
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','physiology',ntag)    !get number of pft tags
  print*,"PHYSIOLOGY READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        
        call libxml2f90__ll_selecttag('DOWN','physiology',i)

        call getConfigINT  ('n_plant_lim','physiology',i,ival,texist)
        if(texist) n_plant_lim = ival
        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif


  !********** INITIAL CONDITIONS
  call libxml2f90__ll_selectlist(TRIM(FILENAME))       
  call libxml2f90__ll_selecttag('ACT','config',1) !select upper level tag
  call libxml2f90__ll_exist('DOWN','initcond',ntag)    !get number of pft tags
  init_fsc = -1.0
  init_stsc = -1.0
  init_ssc = -1.0
  init_stsl = -1.0
  init_fsn = -1.0
  init_msn = -1.0
  
  print*,"INITCOND READ FROM FILE ::",ntag
  if(ntag .ge. 1) then
     do i=1,ntag
        
        call libxml2f90__ll_selecttag('DOWN','initcond',i)

        call getConfigREAL  ('fsc','initcond',i,rval,texist)
        if(texist) init_fsc = rval
        call getConfigREAL  ('stsc','initcond',i,rval,texist)
        if(texist) init_stsc = rval
        call getConfigREAL  ('ssc','initcond',i,rval,texist)
        if(texist) init_ssc = rval
        call getConfigREAL  ('stsl','initcond',i,rval,texist)
        if(texist) init_stsl = rval
        call getConfigREAL  ('fsn','initcond',i,rval,texist)
        if(texist) init_fsn = rval
        call getConfigREAL  ('msn','initcond',i,rval,texist)
        if(texist) init_msn = rval
        

        
        call libxml2f90__ll_selecttag('UP','config',1) !move back up to top level
     enddo
  endif
  


  !********* LOST PARAMETERS
!!$         call getConfigINT  ('estimator','numerics',i,ival,texist)
!!$         if(texist) data%estimator = ival
!!$         call getConfigREAL  ('Vm_amp','numerics',i,rval,texist)
!!$         if(texist) data%Vm_amp = real(rval)
!!$         call getConfigINT  ('n_poi','numerics',i,ival,texist)
!!$         if(texist) data%n_poi = ival
!!$         call getConfigINT  ('max_cohorts','numerics',i,ival,texist)
!!$         if(texist) data%max_cohorts = ival
!!$         call getConfigREAL  ('dbhmax','numerics',i,rval,texist)
!!$         if(texist) data%dbhmax = real(rval)
!!$         call getConfigREAL  ('f_area','community',i,rval,texist)
!!$         if(texist) data%f_area = real(rval)
!!$         call getConfigINT  ('forecast_beg_year','community',i,ival,texist)
!!$         if(texist) data%forecast_beg_year = ival
!!$         call getConfigINT  ('project_landuse_rates','community',i,ival,texist)
!!$         if(texist) data%project_landuse_rates = ival
!!$         call getConfigREAL  ('k_fw','community',i,rval,texist)
!!$         if(texist) data%k_fw = real(rval)
!!$         call getConfigREAL  ('fp1','community',i,rval,texist)
!!$         if(texist) data%fp1 = real(rval)
!!$         call getConfigREAL  ('btol','community',i,rval,texist)
!!$         if(texist) data%btol = real(rval)
!!$         call getConfigREAL  (' theta_crit_lo','community',i,rval,texist)
!!$         if(texist) data%theta_crit_lo = real(rval)
!!$         call getConfigREAL  (' theta_crit_hi','community',i,rval,texist)
!!$         if(texist) data%theta_crit_hi= real(rval)
!!$         call getConfigREAL  ('gee_delay_time','community',i,rval,texist)
!!$         if(texist) data%gee_delay_time= real(rval)
!!$         call getConfigREAL  ('k_nlr','ecosystem',i,rval,texist)
!!$         if(texist) data%k_nlr = real(rval)
!!$         call getConfigREAL  ('nlr_low_temp','ecosystem',i,rval,texist)
!!$         if(texist) data%nlr_low_temp = real(rval)
!!$         call getConfigREAL  ('nlr_slope','ecosystem',i,rval,texist)
!!$         if(texist) data%nlr_slope = real(rval)
!!$         call getConfigINT  ('winter_decay','ecosystem',i,ival,texist)
!!$         if(texist) data%winter_decay = ival
!!$         call getConfigREAL  ('resp_opt_temp','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_opt_temp = real(rval)
!!$         call getConfigREAL  ('resp_tshr','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_tshr = real(rval)
!!$         call getConfigREAL  ('resp_tshl','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_tshl = real(rval)
!!$         call getConfigREAL  ('resp_max_temp','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_max_temp = real(rval)
!!$         call getConfigREAL  ('resp_opt_water','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_opt_water = real(rval)
!!$         call getConfigREAL  ('resp_water_decay','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_water_decay = real(rval)
!!$         call getConfigREAL  ('resp_water_growth','ecosystem',i,rval,texist)
!!$         if(texist) data%resp_water_growth = real(rval)
!!$         call getConfigREAL  ('nitrogen2','ecosystem',i,rval,texist)
!!$         if(texist) data%nitrogen2 = real(rval)
!!$         call getConfigREAL  ('nitrogen1','ecosystem',i,rval,texist)
!!$         if(texist) data%nitrogen1 = real(rval)
!!$
!!$         call getConfigINT  ('phenol_spring_firstyear','settings',i,ival,texist)
!!$         if(texist) data%phenol_spring_firstyear = ival
!!$         call getConfigINT  ('phenol_spring_lastyear','settings',i,ival,texist)
!!$         if(texist) data%phenol_spring_lastyear = ival
!!$         call getConfigINT  ('phenol_fall_firstyear','settings',i,ival,texist)
!!$         if(texist) data%phenol_fall_firstyear = ival
!!$         call getConfigINT  ('phenol_fall_lastyear','settings',i,ival,texist)
!!$         if(texist) data%phenol_fall_lastyear = ival
!!$
!!$         call getConfigINT  ('landuse_flag','settings',i,ival,texist)
!!$         if(texist) data%landuse_flag = ival
!!$         call getConfigINT  ('physiology_flag','settings',i,ival,texist)
!!$         if(texist) data%physiology_flag = ival
!!$         call getConfigINT  ('phenology_flag','settings',i,ival,texist)
!!$         if(texist) data%phenology_flag = ival
!!$         call getConfigINT  ('mortality_flag','settings',i,ival,texist)
!!$         if(texist) data%mortality_flag = ival
!!$         call getConfigINT  ('plant_respiration_flag','settings',i,ival,texist)
!!$         if(texist) data%plresp = ival
!!$         call getConfigSTRING  ('meteorology_filepath','settings',i,cval,texist)
!!$         if(texist) data%meteorology_filepath = trim(cval)
!!$         call getConfigSTRING  ('optimizer_filepath','settings',i,cval,texist)
!!$         if(texist) data%opt_inputs_fn = trim(cval)
!!$         call getConfigREAL  ('grid_resolution','settings',i,rval,texist)
!!$         if(texist) data%grid_resolution = real(rval)


       

end subroutine read_ed_xml_config

subroutine getConfigINT(ctag,ptag,pwhich,val,texist)
  character(*) :: ctag,ptag
  integer(4) :: val,j,pwhich
  logical(4) :: texist
!! Arguments:  same for REAL and STRING versions
!!  ctag = child tag (string)
!!  ptag = parent tag (string)
!!  pwhich = which node with matching parent tag (integer)
!!  val = value extracted from file
!!  texist = did the value exist? (logical)

  j=0
  texist = .false.
  
  call libxml2f90__ll_exist('DOWN',ctag,j)
  if(j .gt. 0) then
     call libxml2f90__ll_selecttag('DOWN',ctag,1)
     call libxml2f90__existid(ctag,texist)
     if(texist) call libxml2f90__ll_geti4(ctag,1,val)
     call libxml2f90__ll_selecttag('UP',ptag,pwhich)
  endif

end subroutine getConfigINT

subroutine getConfigSTRING(ctag,ptag,pwhich,val,texist)
  character(*) :: ctag,ptag,val
  integer(4) :: j,len,pwhich
  logical(4) :: texist
  j=0
  texist = .false.
  
  call libxml2f90__ll_exist('DOWN',ctag,j)
  if(j .gt. 0) then
     call libxml2f90__ll_selecttag('DOWN',ctag,1)
     call libxml2f90__existid(ctag,texist)
     if(texist) then 
        call libxml2f90__ll_getsize(ctag,len)
        call libxml2f90__ll_getch(ctag,len,val)
        val = val(1:len)
     endif
     call libxml2f90__ll_selecttag('UP',ptag,pwhich)
  endif

end subroutine getConfigSTRING

subroutine getConfigREAL(ctag,ptag,pwhich,val,texist)
  character(*) :: ctag,ptag
  integer(4) :: j,pwhich
  real(8)    :: val
  logical(4) :: texist
  j=0
  texist = .false.
  
  call libxml2f90__ll_exist('DOWN',ctag,j)
  if(j .gt. 0) then
     call libxml2f90__ll_selecttag('DOWN',ctag,1)
     call libxml2f90__existid(ctag,texist)
     if(texist) call libxml2f90__ll_getr8(ctag,1,val)
     call libxml2f90__ll_selecttag('UP',ptag,pwhich)
  endif

end subroutine getConfigREAL

subroutine write_ed_xml_config
!!produce a record of parameters used in a run
!  use ed_max_dims, only: n_pft
  use pft_coms
  use hydrology_coms
  use met_driver_coms
  use canopy_radiation_coms
  use disturb_coms
  use phenology_coms
  use physiology_coms
  use decomp_coms
  use fusion_fission_coms
!  use ed_misc_coms, only: sfilout
  use grid_coms, only : ngrids
  use ed_max_dims  !, only : str_len
  use soil_coms    !, only: infiltration_method, dewmax, water_stab_thresh
!  use ed_data
  use ed_misc_coms !, only: ied_init_mode,ffilout,integration_scheme,sfilin,sfilout,thsums_database
  use rk4_coms     !, only : rk4min_veg_temp

  implicit none
!  integer :: ival
  integer(4) :: i,ival
  character(512) :: xfilout 
!  integer :: i
!  character*(*) :: filename
  integer             :: ng

  write(xfilout,"(a)") trim(sfilout)//".xml"

  !! construct list
  call libxml2f90_ll_add_list("OUTCONFIG")
  call libxml2f90_ll_opentag("config")
  !-----------------------------------------------------


  !************   MET  *****************
  call libxml2f90_ll_opentag("met")
        call putConfigREAL  ("met_land_min"   ,met_land_min   )
        call putConfigREAL  ("rshort_min"     ,rshort_min     )
        call putConfigREAL  ("rshort_max"     ,rshort_max     )
        call putConfigREAL  ("rlong_min"      ,rlong_min      )
        call putConfigREAL  ("rlong_max"      ,rlong_max      )
        call putConfigREAL  ("dt_radinterp"   ,dt_radinterp   )
        call putConfigREAL  ("atm_tmp_min"    ,atm_tmp_min    )
        call putConfigREAL  ("atm_tmp_max"    ,atm_tmp_max    )
        call putConfigREAL  ("atm_shv_min"    ,atm_shv_min    )
        call putConfigREAL  ("atm_shv_max"    ,atm_shv_max    )
        call putConfigREAL  ("atm_rhv_min"    ,atm_rhv_min    )
        call putConfigREAL  ("atm_rhv_max"    ,atm_rhv_max    )
        call putConfigREAL  ("atm_co2_min"    ,atm_co2_min    )
        call putConfigREAL  ("atm_co2_max"    ,atm_co2_max    )
        call putConfigREAL  ("prss_min"       ,prss_min       )
        call putConfigREAL  ("prss_max"       ,prss_max       )
        call putConfigREAL  ("pcpg_min"       ,pcpg_min       )
        call putConfigREAL  ("pcpg_max"       ,pcpg_max       )
        call putConfigREAL  ("vels_min"       ,vels_min       )
        call putConfigREAL  ("vels_max"       ,vels_max       )
        call putConfigREAL  ("geoht_min"      ,geoht_min      )
        call putConfigREAL  ("geoht_max"      ,geoht_max      )
        if (print_radinterp) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT   ("print_radinterp",ival           )
        call putConfigSTRING("vbdsf_file"     ,vbdsf_file     )
        call putConfigSTRING("vddsf_file"     ,vddsf_file     )
        call putConfigSTRING("nbdsf_file"     ,nbdsf_file     )
        call putConfigSTRING("nddsf_file"     ,nddsf_file     )
  call libxml2f90_ll_closetag("met")




  !************   MISC  *****************
  call libxml2f90_ll_opentag("misc")
     call putConfigINT("restart_mode",ied_init_mode)
     call putConfigSTRING("output_filepath",ffilout)
     call putConfigSTRING("input_filepath",sfilin(1))
     call putConfigSTRING("history_out_filepath",sfilout)
     call putConfigINT("ivegt_dynamics",ivegt_dynamics)
     call putConfigINT("ibigleaf",ibigleaf)
     call putConfigINT("integration_scheme",integration_scheme)
  call libxml2f90_ll_closetag("misc")

  !************   ED_MISC  *****************
  call libxml2f90_ll_opentag("ed_misc")
     call putConfigINT("restart_target_year",restart_target_year)
     call putConfigINT("burnin",burnin)
     call putConfigINT("vary_elev",vary_elev)
     call putConfigINT("vary_rad",vary_rad)
     call putConfigINT("vary_hyd",vary_hyd)
  call libxml2f90_ll_closetag("ed_misc")

  !************   LAND USE  *****************
!  call libxml2f90_ll_opentag("landuse")
!    do i=1,num_lu_trans
!    end do
!  call libxml2f90_ll_closetag("landuse")

  !************   PFT  *****************
  do i=1,n_pft
     if(include_pft(i)) then !! loop over included PFT's

        call libxml2f90_ll_opentag("pft")

!! GENERAL PFT     
        call putConfigINT("num",i)
        if (is_tropical(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("is_tropical",ival)
        if (is_grass(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("is_grass",ival)
        if (is_conifer(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("is_conifer",ival)
        if (is_savannah(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("is_savannah",ival)
        if (is_liana(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("is_liana",ival)
        if (include_pft(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("include_pft",ival)
        if (include_pft_ag(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("include_pft_ag",ival)
        if (include_pft_fp(i)) then
           ival = 1
        else
           ival = 0
        end if
        call putConfigINT("include_pft_fp",ival)
     
!! CANOPY RADIATION
        call putConfigREAL8("clumping_factor",clumping_factor(i))
        call putConfigREAL8("orient_factor",orient_factor(i))
        call putConfigREAL8("leaf_emiss_tir",leaf_emiss_tir(i))
        call putConfigREAL8("wood_emiss_tir",wood_emiss_tir(i))

        call putConfigREAL8("leaf_reflect_vis",leaf_reflect_vis(i))
        call putConfigREAL8("leaf_reflect_nir",leaf_reflect_vis(i))
        call putConfigREAL8("wood_reflect_vis",leaf_reflect_vis(i))
        call putConfigREAL8("wood_reflect_nir",leaf_reflect_vis(i))

        call putConfigREAL8("leaf_trans_vis",leaf_reflect_vis(i))
        call putConfigREAL8("leaf_trans_nir",leaf_reflect_vis(i))
        call putConfigREAL8("wood_trans_vis",leaf_reflect_vis(i))
        call putConfigREAL8("wood_trans_nir",leaf_reflect_vis(i))

        call putConfigREAL8("leaf_backscatter_vis",leaf_backscatter_vis(i))
        call putConfigREAL8("leaf_backscatter_nir",leaf_backscatter_nir(i))
        call putConfigREAL8("leaf_backscatter_tir",leaf_backscatter_tir(i))

        call putConfigREAL8("wood_backscatter_vis",leaf_backscatter_vis(i))
        call putConfigREAL8("wood_backscatter_nir",leaf_backscatter_nir(i))
        call putConfigREAL8("wood_backscatter_tir",leaf_backscatter_tir(i))

        call putConfigREAL8("leaf_scatter_vis",leaf_scatter_vis(i))
        call putConfigREAL8("leaf_scatter_nir",leaf_scatter_vis(i))
        call putConfigREAL8("wood_scatter_vis",leaf_scatter_vis(i))
        call putConfigREAL8("wood_scatter_nir",leaf_scatter_vis(i))

        call putConfigREAL8("phi1",phi1(i))
        call putConfigREAL8("phi2",phi2(i))
        call putConfigREAL8("mu_bar",mu_bar(i))

!! PHOTOSYNTHESIS
        call putConfigINT("photosyn_pathway",photosyn_pathway(i))
        call putConfigREAL("quantum_efficiency",quantum_efficiency(i))
        call putConfigREAL("Vm0",Vm0(i))
        call putConfigREAL("Vm_low_temp", Vm_low_temp(i))
        call putConfigREAL("Vm_high_temp",Vm_high_temp(i))
        call putConfigREAL("Vm_decay_e",  Vm_decay_e(i))
        call putConfigREAL("vm_hor",      Vm_hor(i))
        call putConfigREAL("vm_q10",      Vm_q10(i))

!! LEAF RESPIRATION
        call putConfigREAL("dark_respiration_factor",dark_respiration_factor(i))
        call putConfigREAL("Rd_low_temp",  Rd_low_temp(i))
        call putConfigREAL("Rd_high_temp", Rd_high_temp(i))
        call putConfigREAL("Rd_decay_e",   Rd_decay_e(i))
        call putConfigREAL("Rd_hor",       Rd_hor(i))
        call putConfigREAL("Rd_q10",       Rd_q10(i))
        call putConfigREAL("Rd0",          Rd0(i))

!! STOMATAL PARAMETERS
        call putConfigREAL("D0",               D0(i))
        call putConfigREAL("stomatal_slope",   stomatal_slope(i))
        call putConfigREAL("cuticular_cond",   cuticular_cond(i))
        call putConfigREAL("water_conductance",water_conductance(i))
        call putConfigREAL("leaf_width",       leaf_width(i))
        call putConfigREAL("branch_diam",      branch_diam(i))


!! RESPIRAION AND TURNOVER
        call putConfigREAL("growth_resp_factor"     ,growth_resp_factor     (i))
        call putConfigREAL("leaf_turnover_rate"     ,leaf_turnover_rate     (i))
        call putConfigREAL("root_turnover_rate"     ,root_turnover_rate     (i))
        call putConfigREAL("sapw_turnover_rate"     ,sapw_turnover_rate     (i))
        call putConfigREAL("bark_turnover_rate"     ,bark_turnover_rate     (i))
        call putConfigREAL("storage_turnover_rate"  ,storage_turnover_rate  (i))
        call putConfigREAL("f_labile_leaf"          ,f_labile_leaf          (i))
        call putConfigREAL("f_labile_stem"          ,f_labile_stem          (i))
        call putConfigREAL("root_respiration_factor",root_respiration_factor(i))
        call putConfigREAL("rrf_low_temp"           ,rrf_low_temp           (i))
        call putConfigREAL("rrf_high_temp"          ,rrf_high_temp          (i))
        call putConfigREAL("rrf_decay_e"            ,rrf_decay_e            (i))
        call putConfigREAL("rrf_hor"                ,rrf_hor                (i))
        call putConfigREAL("rrf_q10"                ,rrf_q10                (i))

!! MORTALITY
        call putConfigREAL("frost_mort",frost_mort(i))
        call putConfigREAL("mort0",mort0(i))
        call putConfigREAL("mort1",mort1(i))
        call putConfigREAL("mort2",mort2(i))
        call putConfigREAL("mort3",mort3(i))
        call putConfigREAL("cbr_severe_stress",cbr_severe_stress(i))
        call putConfigREAL("seedling_mortality",seedling_mortality(i))

        call putConfigREAL("treefall_s_gt"   ,treefall_s_gtht (i))
        call putConfigREAL("treefall_s_lt"   ,treefall_s_ltht (i))
        call putConfigREAL("felling_s_gtharv",felling_s_gtharv(i))
        call putConfigREAL("felling_s_ltharv",felling_s_ltharv(i))
        call putConfigREAL("skid_s_gtharv"   ,skid_s_gtharv   (i))
        call putConfigREAL("skid_s_ltharv"   ,skid_s_ltharv   (i))

        call putConfigREAL("fire_s_min"        ,fire_s_min   (i))
        call putConfigREAL("fire_s_max"        ,fire_s_max   (i))
        call putConfigREAL("fire_s_inter"      ,fire_s_inter (i))
        call putConfigREAL("fire_s_slope"      ,fire_s_slope (i))
 
        call putConfigREAL("plant_min_temp",plant_min_temp(i))

!! ALLOCATION
        call putConfigREAL("rho",rho(i))
        call putConfigREAL("SLA",SLA(i))
        call putConfigREAL("q",q(i))
        call putConfigREAL("sapwood_ratio",sapwood_ratio(i))
        call putConfigREAL("qsw"  ,qsw(i))
        call putConfigREAL("qbark",qbark(i))
        call putConfigREAL("init_density",init_density(i))
        call putConfigREAL("f_bstorage_init",f_bstorage_init(i))

     !! HEIGHT
        call putConfigREAL("b1Ht",       b1Ht(i))
        call putConfigREAL("b2Ht",       b2Ht(i))
        call putConfigREAL("hgt_ref",    hgt_ref(i))
        call putConfigREAL("hgt_min",    hgt_min(i))
        call putConfigREAL("hgt_max",    hgt_max(i))
        call putConfigREAL("min_dbh",    min_dbh(i))
        call putConfigREAL("dbh_crit",   dbh_crit(i))
        call putConfigREAL("dbh_bigleaf",dbh_bigleaf(i))

     !! LEAF
        call putConfigREAL("b1Bl_small", b1Bl_small(i))
        call putConfigREAL("b2Bl_small", b2Bl_small(i))
        call putConfigREAL("b1Bl_large", b1Bl_large(i))
        call putConfigREAL("b2Bl_large", b2Bl_large(i))

     !! STEM
        call putConfigREAL("b1Bs_small",b1Bs_small(i))
        call putConfigREAL("b1Bs_large",b1Bs_large(i))
        call putConfigREAL("b2Bs_small",b2Bs_small(i))
        call putConfigREAL("b2Bs_large",b2Bs_large(i))
        call putConfigREAL("min_bdead", min_bdead(i))
        call putConfigREAL("bdead_crit",bdead_crit(i))

     !! CANOPY
        call putConfigREAL("b1Ca",      b1Ca(i))
        call putConfigREAL("b2Ca",      b2Ca(i))

     !! BRANCHES
        call putConfigREAL("b1WAI_small", b1WAI_small(i))
        call putConfigREAL("b2WAI_small", b2WAI_small(i))
        call putConfigREAL("b1WAI_large", b1WAI_large(i))
        call putConfigREAL("b2WAI_large", b2WAI_large(i))
        call putConfigREAL("brf_wd"     , brf_wd     (i))

     !! BARK/SAPWOOD THICKNESS
        call putConfigREAL("qrhob",   qrhob(i))
        call putConfigREAL("b1Xb",    b1Xb(i))
        call putConfigREAL("b1Xs",    b1Xs(i))

     !! COARSE ROOTS
        call putConfigREAL("agf_bs",     agf_bs(i))
        call putConfigREAL("b1Vol",      b1Vol(i))
        call putConfigREAL("b2Vol",      b2Vol(i))
        call putConfigREAL("b1Rd",       b1Rd(i))
        call putConfigREAL("b2Rd",       b2Rd(i))
        call putConfigREAL("init_laimax",init_laimax(i))

     !! NITRO
        call putConfigREAL("c2n_leaf",   c2n_leaf(i))

     !! LEAF DEPENDENT
        call putConfigINT("phenology",         phenology(i))

     !! SPECIFIC HEAT
        call putConfigREAL("c_grn_leaf_dry",    c_grn_leaf_dry(i))
        call putConfigREAL("c_ngrn_wood_dry",   c_ngrn_wood_dry(i))
        call putConfigREAL("c_ngrn_bark_dry",   c_ngrn_bark_dry(i))
        call putConfigREAL("wat_dry_ratio_leaf",wat_dry_ratio_leaf(i))
        call putConfigREAL("wat_dry_ratio_wood",wat_dry_ratio_wood(i))
        call putConfigREAL("wat_dry_ratio_bark",wat_dry_ratio_bark(i))
        call putConfigREAL("delta_c_wood",      delta_c_wood(i))
        call putConfigREAL("delta_c_bark",      delta_c_bark(i))

     !! CROWN DEPTH
        call putConfigREAL("b1Cl",              b1Cl(i))
        call putConfigREAL("b2Cl",              b2Cl(i))

     !! REPRODUCTION
        call putConfigREAL("r_fract", r_fract(i))
        call putConfigREAL("st_fract",st_fract(i))
        call putConfigREAL("nonlocal_dispersal",nonlocal_dispersal(i))
        call putConfigREAL("repro_min_h",repro_min_h(i))
        call putConfigREAL("min_recruit_size",min_recruit_size(i))

     !! OTHER
        call putConfigREAL("seed_rain",        seed_rain(i))

        call libxml2f90_ll_closetag("pft")
     endif
  end do
 
  !************   PFT CONSTANTS  *****************
  call libxml2f90_ll_opentag("pftconst")
     call putConfigREAL("c2n_slow",c2n_slow)
     call putConfigREAL("c2n_structural",c2n_structural)
     call putConfigREAL("l2n_stem",l2n_stem)
     call putConfigREAL("C2B",C2B)
     call putConfigREAL("h_edge",h_edge)
     call putConfigREAL("liana_dbh_crit",liana_dbh_crit)
  call libxml2f90_ll_closetag("pftconst")

  !************   HYDROLOGY  *****************
  call libxml2f90_ll_opentag("hydro")
     call putConfigINT("useTOPMODEL",useTOPMODEL)
     call putConfigINT("useRUNOFF",useRUNOFF)
     call putConfigINT("outputPeriod",HydroOutputPeriod)
     call putConfigREAL("MoistRateTuning",MoistRateTuning)
     call putConfigREAL("MoistSatThresh",MoistSatThresh)
     call putConfigREAL("MoistdWT",Moist_dWT)
     call putConfigREAL("FracLiqRunoff",FracLiqRunoff)
     call putConfigREAL("runoff_vmax",runoff_vmax)
     call putConfigREAL("GrassLAImax",GrassLAImax)
  call libxml2f90_ll_closetag("hydro")

  !************   CLIMATE SCENARIO  *****************
  call libxml2f90_ll_opentag("scenario")
     call putConfigREAL("atm_tmp_intercept",atm_tmp_intercept)
     call putConfigREAL("atm_tmp_slope",atm_tmp_slope)
     call putConfigREAL("prec_intercept",prec_intercept)
     call putConfigREAL("prec_slope",prec_slope)
     call putConfigINT("humid_scenario",humid_scenario)
  call libxml2f90_ll_closetag("scenario")

  !************   LAPSE PARMS  *****************
  call libxml2f90_ll_opentag("lapse")
     call putConfigREAL("geoht",lapse%geoht)
     call putConfigREAL("vels",lapse%vels)
     call putConfigREAL("atm_ustar",lapse%atm_ustar)
     call putConfigREAL("atm_tmp",lapse%atm_tmp)
     call putConfigREAL("rv",lapse%atm_shv)
     call putConfigREAL("prss",lapse%prss)
     call putConfigREAL("pcpg",lapse%pcpg)
     call putConfigREAL("atm_co2",lapse%atm_co2)
     call putConfigREAL("rlong",lapse%rlong)
     call putConfigREAL("par_diffuse",lapse%par_diffuse)
     call putConfigREAL("par_beam",lapse%par_beam)
     call putConfigREAL("nir_diffuse",lapse%nir_diffuse)
     call putConfigREAL("nir_beam",lapse%nir_beam)
     call putConfigREAL("pptnorm",lapse%pptnorm)
  call libxml2f90_ll_closetag("lapse")

  !************   CANOPY RADIATION  *****************
  call libxml2f90_ll_opentag("radiation")
     call putConfigREAL("rlong_min",prec_slope)
     call putConfigREAL8("veg_temp_min",rk4min_veg_temp)
  call libxml2f90_ll_closetag("radiation")

  !************   SOILS  *****************
  call libxml2f90_ll_opentag("soil")
     call putConfigREAL("water_stab_thresh",water_stab_thresh)
     call putConfigINT("infiltration_method",infiltration_method)
     call putConfigREAL("dewmax",dewmax)
     call putConfigSTRING("soilstate_db",soilstate_db)
     call putConfigSTRING("soildepth_db",soildepth_db)
     call putConfigINT("isoilstateinit",isoilstateinit)
     call putConfigINT("isoildepthflg",isoildepthflg)
     call putConfigREAL("runoff_time",runoff_time)
     call libxml2f90_ll_opentag("grid")
        do ng=1,ngrids
           call putConfigSTRING("vegetation_database",veg_database(ng))
           call putConfigSTRING("soil_database",soil_database(ng))
        end do
     call libxml2f90_ll_closetag("grid")

  call libxml2f90_ll_closetag("soil")

  !************   DECOMPOSITION  *****************
  call libxml2f90_ll_opentag("decomposition")
     call putConfigREAL("cwd_frac",cwd_frac)
     call putConfigREAL("resp_opt_water",resp_opt_water)
     call putConfigREAL("resp_water_below_opt",resp_water_below_opt)
     call putConfigREAL("resp_water_above_opt",resp_water_above_opt)
     call putConfigREAL("resp_temperature_increase",resp_temperature_increase)
     call putConfigREAL("N_immobil_supply_scale",N_immobil_supply_scale)
     call putConfigREAL("r_fsc",r_fsc)
     call putConfigREAL("r_stsc",r_stsc)
     call putConfigREAL("r_ssc",r_ssc)
     call putConfigREAL("K1",decay_rate_stsc)
     call putConfigREAL("K2",decay_rate_fsc)
     call putConfigREAL("K3",decay_rate_ssc)
     call putConfigREAL("decay_rate_stsc",decay_rate_stsc)
     call putConfigREAL("decay_rate_fsc",decay_rate_fsc)
     call putConfigREAL("decay_rate_ssc",decay_rate_ssc)
     call putConfigINT ("N_decomp_lim",N_decomp_lim)
     call putConfigREAL("rh_decay_low",rh_decay_low)
     call putConfigREAL("rh_decay_high",rh_decay_high)
     call putConfigREAL("rh_low_temp",rh_low_temp)
     call putConfigREAL("rh_high_temp",rh_high_temp)
     call putConfigREAL("rh_decay_dry",rh_decay_dry)
     call putConfigREAL("rh_decay_wet",rh_decay_wet)
     call putConfigREAL("rh_dry_smoist",rh_dry_smoist)
     call putConfigREAL("rh_wet_smoist",rh_wet_smoist)

  call libxml2f90_ll_closetag("decomposition")

  !************   FUSION/FISSION  *****************
  call libxml2f90_ll_opentag("fusefiss")
     call putConfigINT  ("ff_nhgt"            ,ff_nhgt            )
     !----- Old patch/cohort fusion parameters
     call putConfigREAL ("dark_cumlai_min"    ,dark_cumlai_min    )
     call putConfigREAL ("dark_cumlai_max"    ,dark_cumlai_max    )
     call putConfigREAL ("sunny_cumlai_min"   ,sunny_cumlai_min   )
     call putConfigREAL ("sunny_cumlai_max"   ,sunny_cumlai_max   )
     call putConfigREAL ("light_toler_min"    ,light_toler_min    )
     call putConfigREAL ("light_toler_max"    ,light_toler_max    )
     call putConfigREAL ("sunny_cumlai_mult"  ,sunny_cumlai_mult  )
     call putConfigREAL ("dark_cumlai_mult"   ,dark_cumlai_mult   )
     call putConfigREAL ("light_toler_mult"   ,light_toler_mult   )
     call putConfigREAL ("fusetol"            ,fusetol            )
     call putConfigREAL ("fusetol_h"          ,fusetol_h          )
     call putConfigREAL ("lai_fuse_tol"       ,lai_fuse_tol       )
     call putConfigREAL ("coh_tolerance_max"  ,coh_tolerance_max  )
     if (fuse_relax) then
        ival = 1
     else
        ival = 0
     end if
     call putConfigINT  ("fuse_relax"         ,ival               )
     !------ New patch/cohort fusion parameters
     call putConfigINT  ("niter_patfus"       ,niter_patfus       )
     call putConfigREAL ("lai_fuse_tol"       ,lai_fuse_tol       )
     call putConfigREAL ("pat_light_tol_min"  ,pat_light_tol_min  )
     call putConfigREAL ("pat_light_tol_max"  ,pat_light_tol_max  )
     call putConfigREAL ("pat_light_tol_mult" ,pat_light_tol_mult )
     call putConfigREAL ("pat_light_mxd_fac"  ,pat_light_mxd_fac  )
     call putConfigREAL ("pat_diff_age_tol"   ,pat_diff_age_tol   )
     call putConfigREAL ("pat_min_area_remain",pat_min_area_remain)
     call putConfigINT  ("niter_cohfus"       ,niter_cohfus       )
     call putConfigREAL ("coh_size_tol_min"   ,coh_size_tol_min   )
     call putConfigREAL ("coh_size_tol_max"   ,coh_size_tol_max   )
     call putConfigREAL ("coh_size_tol_mult"  ,coh_size_tol_mult  )
     call putConfigREAL ("lai_tol"            ,lai_tol            )
  call libxml2f90_ll_closetag("fusefiss")



  !************   HRZSHADE  *****************
  call libxml2f90_ll_opentag("hrzshade")
     call putConfigREAL ("cci_radius" ,cci_radius )
     call putConfigREAL ("cci_pixres" ,cci_pixres )
     call putConfigREAL ("cci_gapsize",cci_gapsize)
     call putConfigREAL ("cci_gapmin" ,cci_gapmin )
     call putConfigINT  ("cci_nretn"  ,cci_nretn  )
     call putConfigREAL ("cci_hmax"   ,cci_hmax   )
  call libxml2f90_ll_closetag("hrzshade")




  !************   DISTURBANCE  *****************
  call libxml2f90_ll_opentag("disturbance")
     ! --- General
     call putConfigREAL("min_new_patch_area",min_patch_area)
     call putConfigREAL("min_patch_area",min_patch_area)
     call putConfigINT("ianth_disturb",ianth_disturb)
     ! --- Treefall
     call putConfigREAL("treefall_disturbance_rate",treefall_disturbance_rate)
     call putConfigREAL("Time2Canopy",Time2Canopy)
     call putConfigREAL("treefall_hite_threshold",treefall_hite_threshold)
     ! --- Forestry
     call putConfigINT("forestry_on",forestry_on)
     call putConfigINT("agriculture_on",agriculture_on)
     call putConfigINT("plantation_year",plantation_year)
     call putConfigREAL("plantation_rotation",plantation_rotation)
     call putConfigREAL("min_harvest_biomass",min_harvest_biomass)
     call putConfigREAL("mature_harvest_age",mature_harvest_age)
     ! --- Fire
     call putConfigINT("include_fire"           ,include_fire          )
     call putConfigREAL("fire_dryness_threshold",fire_dryness_threshold)
     call putConfigREAL("fire_parameter"        ,fire_parameter        )
     call putConfigREAL("fire_smoist_depth"     ,fire_smoist_depth     )
     call putConfigREAL("fuel_height_max"       ,fuel_height_max       )
     call putConfigREAL("f_combusted_fast"      ,f_combusted_fast      )
     call putConfigREAL("f_combusted_struct"    ,f_combusted_struct    )
     call putConfigREAL("agf_fsc"               ,agf_fsc               )
     call putConfigREAL("agf_stsc"              ,agf_stsc              )
  call libxml2f90_ll_closetag("disturbance")

  !************   PHENOLOGY  *****************
  call libxml2f90_ll_opentag("phenology")
     call putConfigREAL("retained_carbon_fraction",retained_carbon_fraction)
     call putConfigREAL("theta_crit",thetacrit)
     call putConfigREAL("dl_tr",dl_tr)
     call putConfigREAL("st_tr1",st_tr1)
     call putConfigREAL("st_tr2",st_tr2)
     call putConfigREAL("phen_a",phen_a)
     call putConfigREAL("phen_b",phen_b)
     call putConfigREAL("phen_c",phen_c)
     call putConfigINT("iphen_scheme",iphen_scheme)
     call putConfigINT("iphenys1",iphenys1)
     call putConfigINT("iphenysf",iphenysf)
     call putConfigINT("iphenyf1",iphenyf1)
     call putConfigINT("iphenyff",iphenyff)
  call libxml2f90_ll_closetag("phenology")

  !************   PHYSIOLOGY  *****************
  call libxml2f90_ll_opentag("physiology")
     call putConfigINT("n_plant_lim",n_plant_lim)
  call libxml2f90_ll_closetag("physiology")

  !************   INITIAL CONDITIONS  *****************
  call libxml2f90_ll_opentag("initcond")
     call putConfigREAL("fsc",init_fsc)
     call putConfigREAL("stsc",init_stsc)
     call putConfigREAL("ssc",init_ssc)
     call putConfigREAL("stsl",init_stsl)
     call putConfigREAL("fsn",init_fsn)
     call putConfigREAL("msn",init_msn)
  call libxml2f90_ll_closetag("initcond")

  !-----------------------------------------------------
  call libxml2f90_ll_closetag("config")
  !! write list
  print*,"Wrote Config Record:", trim(xfilout)
  open(12,file=trim(xfilout),form='formatted',status='replace')
  call libxml2f90__ll_report("OUTCONFIG",12,.false.)
  close(12)

end subroutine write_ed_xml_config


subroutine putConfigSTRING(tag,value)
  character(*),intent(in) :: tag 
  character(*),intent(in) :: value
  integer :: lenval 
  lenval = len(value)
  call libxml2f90_ll_opentag(tag)
  call libxml2f90_ll_addid(trim(tag),lenval,trim(value))
  call libxml2f90_ll_closetag(tag)
end subroutine putConfigSTRING

subroutine putConfigINT(tag,ivalue)
  use ed_max_dims, only : str_len
  character(*),intent(in) :: tag 
  integer,intent(in) :: ivalue
  character(str_len) :: value
  integer :: lenval 
  write(value,"(i11.1)") ivalue
  lenval = len(trim(value))
  call libxml2f90_ll_opentag(tag)
  call libxml2f90_ll_addid(trim(tag),lenval,trim(value))
  call libxml2f90_ll_closetag(tag)
end subroutine putConfigINT

subroutine putConfigREAL(tag,rvalue)
  use ed_max_dims, only : str_len
  character(*),intent(in) :: tag 
  real,intent(in) :: rvalue
  character(str_len) :: value
  integer :: lenval 
  write(value,"(f20.10)") rvalue
  lenval = len(trim(value))
  call libxml2f90_ll_opentag(tag)
  call libxml2f90_ll_addid(trim(tag),lenval,trim(value))
  call libxml2f90_ll_closetag(tag)
end subroutine putConfigREAL

subroutine putConfigREAL8(tag,rvalue)
  use ed_max_dims, only : str_len
  character(*),intent(in) :: tag 
  real(kind=8),intent(in) :: rvalue
  character(str_len) :: value
  integer :: lenval 
  write(value,"(f40.20)") rvalue
  lenval = len(trim(value))
  call libxml2f90_ll_opentag(tag)
  call libxml2f90_ll_addid(trim(tag),lenval,trim(value))
  call libxml2f90_ll_closetag(tag)
end subroutine putConfigREAL8

