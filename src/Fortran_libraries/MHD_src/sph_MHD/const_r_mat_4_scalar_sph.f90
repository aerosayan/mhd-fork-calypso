!>@file   const_r_mat_4_scalar_sph.f90
!!@brief  module const_r_mat_4_scalar_sph
!!
!!@date  Programmed by H.Matsui on Apr., 2009
!
!>@brief Construct matrix for time evolution of scalar fields
!!
!!@verbatim
!!      subroutine const_radial_mat_4_temp_sph
!!      subroutine const_radial_mat_4_composit_sph
!!      subroutine const_radial_mat_4_press_sph
!!@endverbatim
!
      module const_r_mat_4_scalar_sph
!
      use m_precision
      use calypso_mpi
!
      use m_constants
      use m_machine_parameter
      use m_t_int_parameter
!
      implicit none
!
      private :: const_radial_mat_4_scalar_sph
!
! -----------------------------------------------------------------------
!
      contains
!
! -----------------------------------------------------------------------
!
      subroutine const_radial_mat_4_temp_sph
!
      use m_spheric_parameter
      use m_boundary_params_sph_MHD
      use m_radial_matrices_sph
      use m_physical_property
!
!
      call const_radial_mat_4_scalar_sph(nidx_rj(1), nidx_rj(2),        &
     &    sph_bc_T, coef_imp_t, coef_temp, coef_d_temp, temp_evo_mat,   &
     &    temp_evo_lu, temp_evo_det, i_temp_pivot)
!
      if(i_debug .eq. iflag_full_msg)                                   &
     &     call check_temp_matrices_sph(my_rank)
!
      end subroutine const_radial_mat_4_temp_sph
!
! -----------------------------------------------------------------------
!
      subroutine const_radial_mat_4_composit_sph
!
      use m_spheric_parameter
      use m_boundary_params_sph_MHD
      use m_radial_matrices_sph
      use m_physical_property
!
!
      call const_radial_mat_4_scalar_sph(nidx_rj(1), nidx_rj(2),        &
     &    sph_bc_C, coef_imp_c, coef_light, coef_d_light,               &
     &    composit_evo_mat, composit_evo_lu, composit_evo_det,          &
     &    i_composit_pivot)
!
      if(i_debug .eq. iflag_full_msg)                                   &
     &       call check_composit_matrix_sph(my_rank)
!
      end subroutine const_radial_mat_4_composit_sph
!
! -----------------------------------------------------------------------
! -----------------------------------------------------------------------
!
      subroutine const_radial_mat_4_press_sph
!
      use m_spheric_parameter
      use m_spheric_param_smp
      use m_physical_property
      use m_boundary_params_sph_MHD
      use m_coef_fdm_to_center
      use m_coef_fdm_free_ICB
      use m_coef_fdm_free_CMB
      use m_ludcmp_3band
      use set_sph_scalar_mat_bc
      use cal_inner_core_rotation
      use center_sph_matrices
      use mat_product_3band_mul
      use set_radial_mat_sph
!
      integer(kind = kint) :: ip, jst, jed, j
      integer(kind = kint) :: ierr
      real(kind = kreal) :: coef_p
!
!
      coef_p = - coef_press
      call set_unit_mat_4_poisson(nidx_rj(1), nidx_rj(2),               &
     &    sph_bc_U%kr_in, sph_bc_U%kr_out, p_poisson_mat)
      call add_scalar_poisson_mat_sph(nidx_rj(1), nidx_rj(2),           &
     &    sph_bc_U%kr_in, sph_bc_U%kr_out, coef_p, p_poisson_mat)
!
!   Boundary condition for ICB
!
      if(sph_bc_U%iflag_icb .eq. iflag_sph_fill_center) then
        call add_scalar_poisson_mat_ctr1(nidx_rj(1), nidx_rj(2),        &
     &       sph_bc_U%r_ICB, fdm2_fix_fld_ctr1, coef_p, p_poisson_mat)
      else
        call add_icb_scalar_poisson_mat(nidx_rj(1), nidx_rj(2),         &
     &      sph_bc_U%kr_in, sph_bc_U%r_ICB, sph_bc_U%fdm2_fix_dr_ICB,   &
     &      coef_p, p_poisson_mat)
      end if
!
!   Boundary condition for CMB
!
      call add_cmb_scalar_poisson_mat(nidx_rj(1), nidx_rj(2),           &
     &    sph_bc_U%kr_out, sph_bc_U%r_CMB, sph_bc_U%fdm2_fix_dr_CMB,    &
     &    coef_p, p_poisson_mat)
!
!$omp parallel do private(jst,jed,j)
      do ip = 1, np_smp
        jst = idx_rj_smp_stack(ip-1,2) + 1
        jed = idx_rj_smp_stack(ip,  2)
        do j = jst, jed
          call ludcmp_3band(nidx_rj(1), p_poisson_mat(1,1,j),           &
     &        i_p_pivot(1,j), ierr, p_poisson_lu(1,1,j),                &
     &        p_poisson_det(1,j) )
        end do
      end do
!$omp end parallel do
!
      end subroutine const_radial_mat_4_press_sph
!
! -----------------------------------------------------------------------
! -----------------------------------------------------------------------
!
      subroutine const_radial_mat_4_scalar_sph                          &
     &         (nri, jmax, sph_bc, coef_imp, coef_f, coef_d,            &
     &          evo_mat3, evo_lu, evo_det, i_pivot)
!
      use m_spheric_param_smp
      use m_coef_fdm_to_center
      use m_ludcmp_3band
      use t_boundary_params_sph_MHD
      use center_sph_matrices
      use set_radial_mat_sph
      use set_sph_scalar_mat_bc
!
      integer(kind = kint), intent(in) :: nri, jmax
      type(sph_boundary_type), intent(in) :: sph_bc
      real(kind = kreal), intent(in) :: coef_imp, coef_f, coef_d
      real(kind = kreal), intent(inout) :: evo_mat3(3,nri,jmax)
      real(kind = kreal), intent(inout) :: evo_lu(5,nri,jmax)
      real(kind = kreal), intent(inout) :: evo_det(nri,jmax)
      integer(kind = kint), intent(inout) :: i_pivot(nri,jmax)
!
      integer(kind = kint) :: ip, jst, jed, j
      integer(kind = kint) :: ierr
!
      real(kind = kreal) :: coef
!
!
      if(coef_f .eq. zero) then
        coef = one
        call set_unit_mat_4_poisson                                     &
     &     (nri, jmax, sph_bc%kr_in, sph_bc%kr_out, evo_mat3)
      else
        coef = coef_imp * coef_d * dt
        call set_unit_mat_4_time_evo(nri, jmax, evo_mat3)
      end if
!
      call add_scalar_poisson_mat_sph                                   &
     &   (nri, jmax, sph_bc%kr_in, sph_bc%kr_out, coef, evo_mat3)
!
      if     (sph_bc%iflag_icb .eq. iflag_sph_fill_center               &
     &   .or. sph_bc%iflag_icb .eq. iflag_sph_fix_center) then
        call add_scalar_poisson_mat_ctr1(nri, jmax,                     &
     &      sph_bc%r_ICB, fdm2_fix_fld_ctr1, coef, evo_mat3)
      else if (sph_bc%iflag_icb .eq. iflag_fixed_flux) then
        call add_fix_flux_icb_poisson_mat(nri, jmax, sph_bc%kr_in,      &
     &      sph_bc%r_ICB, sph_bc%fdm2_fix_dr_ICB, coef, evo_mat3)
      else
        call set_fix_fld_icb_poisson_mat                                &
     &     (nri, jmax, sph_bc%kr_in, evo_mat3)
      end if
!
      if (sph_bc%iflag_cmb .eq. iflag_fixed_flux) then
        call add_fix_flux_cmb_poisson_mat(nri, jmax, sph_bc%kr_out,     &
     &      sph_bc%r_CMB, sph_bc%fdm2_fix_dr_CMB, coef, evo_mat3)
      else
        call set_fix_fld_cmb_poisson_mat                                &
     &     (nri, jmax, sph_bc%kr_out, evo_mat3)
      end if
!
!$omp parallel do private(jst,jed,j)
      do ip = 1, np_smp
        jst = idx_rj_smp_stack(ip-1,2) + 1
        jed = idx_rj_smp_stack(ip,  2)
        do j = jst, jed
          call ludcmp_3band(nri, evo_mat3(1,1,j), i_pivot(1,j),  &
     &        ierr, evo_lu(1,1,j), evo_det(1,j))
        end do
      end do
!$omp end parallel do
!
      end subroutine const_radial_mat_4_scalar_sph
!
! -----------------------------------------------------------------------
!
      end module const_r_mat_4_scalar_sph
