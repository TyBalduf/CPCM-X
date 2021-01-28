module initialize_cosmo

   contains
      subroutine read_cosmo(compound,elements,ident,xyz,charges,area,pot,volume,c_energy,atom_xyz)
         use globals
         implicit none
         character(*), intent(in) :: compound
         character(50) :: line, ld1,ld2, ld3, ld4, ld5, ld6
         real(8), dimension(:), allocatable,intent(out) :: charges,&
            &area,pot
         real(8), dimension(:,:), allocatable, intent(out) :: xyz, atom_xyz
         character(2), allocatable, dimension(:),intent(out) :: elements
         real(8), intent(out) :: volume, c_energy
         integer :: i, io_error, dummy1, dummy2, num
         real(8) :: dummy3, dummy4, dummy5
         real(8), dimension(:), allocatable :: ident
         character(2) :: element
         
         logical :: exists

         INQUIRE(file=compound,EXIST=exists)
   
         if (.NOT. exists) then
            write(*,*) "COSMO file does not exists."
            stop
         end if

         open(1,file=compound,iostat=io_error)

         if (io_error .NE. 0) then
            write(*,*) "Problem while reading COSMO input. &
               &Check your data."
            stop
         end if

         io_error=0 
         do while (io_error .GE. 0)
            read(1,*,iostat=io_error) line
         end do
         read(line,*) num
         allocate(charges(num))
         allocate(ident(num))
         allocate(area(num))
         allocate(xyz(num,3))
         allocate(pot(num))
         rewind(1)
         ident(:)=0
         do while (line .NE. "$segment_information")
            read(1,*) line
         end do
         
         num=1
         dummy4=0
         do while (.TRUE.)
            read(1,'(A1)',advance='no',iostat=io_error) line
            if (line=="#") then
               read(1,*)
               cycle
            else if (io_error .LT. 0) then
               exit
            else
               read(1,*) dummy1,ident(num),xyz(num,1),xyz(num,2),&
                  &xyz(num,3),dummy3,area(num),charges(num),pot(num)
            !   charges(num)=anint(charges(num)*1000)/1000
               pot(num)=pot(num)*BtoA
               xyz(num,1)=xyz(num,1)*btoa
               xyz(num,2)=xyz(num,2)*btoa
               xyz(num,3)=xyz(num,3)*btoa
               num=num+1
            end if
         end do
         rewind(1)
         do while (line .NE. "#atom")
            read(1,*) line
         end do
         
         allocate(elements(int(maxval(ident))))
         allocate(atom_xyz(int(maxval(ident)),3))

         do while (.TRUE.)
            read(1,'(A1)',advance='no',iostat=io_error) line
            if (line .NE. "$") then
               read(1,*) dummy1, dummy3, dummy4, dummy5, element
               elements(dummy1)=element
               atom_xyz(dummy1,1)=dummy3*btoa
               atom_xyz(dummy1,2)=dummy4*btoa
               atom_xyz(dummy1,3)=dummy5*btoa
            else
               exit
            end if
         end do
   !      write(*,*) elements
         rewind(1)
         do while (line .NE. "area=")
            read(1,*) line
         end do

         read(1,*) line, volume

         rewind(1)
         do while (line .NE. "$cosmo_energy")
            read(1,*) line
         end do
         read (1,*)
         read (1,*) line,ld1,ld2,ld3,ld4,ld5,ld6,c_energy
   
         
         close(1)
        
      end subroutine read_cosmo

      subroutine initialize_param(r_cav,disp_con)
         use element_dict
         use globals
         implicit none

         !real(8), dimension(10) :: param
         type(DICT_STRUCT), pointer, intent(inout) :: r_cav, disp_con

         type(DICT_DATA) :: data1, r_c, d_c
         character(len=3) :: symbol
         logical :: g_exists
         integer :: i, io_error,dummy1
         character(len=100) :: home,param_path

         
         Call get_environment_variable("CSMHOME", home,dummy1,io_error,.TRUE.)
         if (io_error .EQ. 0) then
            param_path=trim(home)//"/"//trim(model)//".param"
         else if (io_error .EQ. 1) then
            param_path=trim(model)//".param"
         end if
        ! write(*,*) param_path
         INQUIRE(file=param_path, exist=g_exists)
      
         if (g_exists) then
            write(*,*) "Reading COSMO Parameters from "//trim(model)//".param"
            open(1,file=param_path)

            select case (trim(model))
               case("crs")

                  ! Setting global COSMO-RS Parameters from parameter file

                  read(1,*) param(1)
                  param(2)=2.0_8*param(1)
                  do i=3,10
                     read(1,*) param(i)
                  end do
                  read(1,*)
                  io_error=0

            ! Creating element specific Parameter Dictionaries from parameter file

                  read(1,*) symbol, r_c%param, d_c%param
                  Call dict_create(r_cav, trim(symbol), r_c)
                  Call dict_create(disp_con, trim(symbol), d_c)
                  do while (io_error .GE. 0)
                     read(1,*,iostat=io_error) symbol, r_c%param, d_c%param
                     Call dict_add_key(r_cav, trim(symbol), r_c)
                     Call dict_add_key(disp_con,trim(symbol), d_c)
                  end do
               case("sac")

                  ! Setting global COSMO-SAC Parameters from parameter file

                  read(1,*) param(1)
                  io_error=0
                  do i=2,8
                     read(1,*,iostat=io_error) param(i)
                  end do

               case("sac2010")

                  do i=1,10
                     read(1,*) param(i)
                  end do

               case("sac2013")

                  do i=1,10
                     read(1,*) param(i)
                  end do
                  read(1,*)
                  io_error=0

                  read(1,*) symbol, d_c%param
                  Call dict_create(disp_con, trim(symbol), d_c)
                  do while (io_error .GE. 0)
                     read(1,*,iostat=io_error) symbol, d_c%param
                     Call dict_add_key(disp_con,trim(symbol), d_c)
                  end do

               case default
                  write(*,*) model//" is not a defined model!"
                  stop
            end select

         else
            write(*,*) "No COSMO Parameter File found, exiting."
            stop
         end if

            !Hard Coded Covalent Radii

            data1%param=0.31_8
            call dict_create(cov_r, 'h', data1)
            data1%param=0.76_8
            call dict_add_key(cov_r, 'c', data1)
            data1%param=0.66_8
            call dict_add_key(cov_r, 'o', data1)
     


      end subroutine initialize_param

      subroutine getargs(solvent,solute,T,sig_in)
         use globals
         implicit none
         integer :: i
         character(len=20),intent(out) ::solvent, solute
         real(8),intent(out) :: T
         logical, intent(out) :: sig_in

         character(len=20) :: arg

         T=298.15_8
         solute=''
         solvent=''
         sig_in=.FALSE.
         model="sac"
         do i=1,command_argument_count()

         Call get_command_argument(i, arg) 
            Select case (arg)
               case ("--c")
                  Call get_command_argument(i+1,arg)
                  solute=arg
               case ("--s")
                  Call get_command_argument(i+1,arg)
                  solvent=arg
               case ("--T")
                  Call get_command_argument(i+1,arg)
                  read(arg,*) T
               case ("--model")
                  Call get_command_argument(i+1,arg)
                  read(arg,*) model
               case ("--sigma")
                  sig_in=.TRUE.
               case default
                  cycle
            end select
         end do
         SysTemp=T
      end subroutine getargs
end module initialize_cosmo
