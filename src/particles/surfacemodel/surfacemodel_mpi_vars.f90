!==================================================================================================================================
! Copyright (c) 2015 - 2019 Wladimir Reschke
!
! This file is part of PICLas (gitlab.com/piclas/piclas). PICLas is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3
! of the License, or (at your option) any later version.
!
! PICLas is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with PICLas. If not, see <http://www.gnu.org/licenses/>.
!==================================================================================================================================
#include "piclas.h"

MODULE MOD_SurfaceModel_MPI_Vars
!===================================================================================================================================
! Contains global variables provided by the particle surfaces routines
!===================================================================================================================================
! MODULES
!USE mpi
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PUBLIC
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! required variables
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
#if USE_MPI
TYPE tMPIMessage
  REAL,ALLOCATABLE             :: content(:)                                 ! message buffer real
  LOGICAL,ALLOCATABLE          :: content_log(:)                             ! message buffer logical for BGM
  INTEGER,ALLOCATABLE          :: content_int(:)                             ! message buffer for integer for adsorption
END TYPE

TYPE(tMPIMessage),ALLOCATABLE  :: SurfDistRecvBuf(:)                         ! SurfDistRecvBuf with all requried types
TYPE(tMPIMessage),ALLOCATABLE  :: SurfDistSendBuf(:)                         ! SurfDistSendBuf with all requried types

TYPE tDistNbrComm
  INTEGER,ALLOCATABLE :: nPosSend(:) ! number of distribution site to send for surface (nSidesSend,nCoordination)
  INTEGER,ALLOCATABLE :: nPosRecv(:) ! number of distribution sites to receive for surface (nSidesRecv,nCoordination)
END TYPE

TYPE tSurfModelMPIExchange
  INTEGER,ALLOCATABLE            :: nH2OSidesSend(:)         ! number of sides to send from halo to origin sides of neighbors
  INTEGER,ALLOCATABLE            :: nH2OSidesRecv(:)         ! number of sides to recv from neigh halo to own origin sides
  TYPE(tMPIMessage),ALLOCATABLE  :: H2OSendBuf(:)            ! Send buffer for halo to origin comm
  TYPE(tMPIMessage),ALLOCATABLE  :: H2ORecvBuf(:)            ! Recieve buffer for halo to origin comm

  INTEGER,ALLOCATABLE            :: nO2HSidesSend(:)         ! number of sides to send from origin to halo sides of neighbors
  INTEGER,ALLOCATABLE            :: nO2HSidesRecv(:)         ! number of sides to recv from neigh origin to own halo sides
  TYPE(tMPIMessage),ALLOCATABLE  :: O2HSendBuf(:)            ! Send buffer for origin to halo comm
  TYPE(tMPIMessage),ALLOCATABLE  :: O2HRecvBuf(:)            ! Recieve buffer for origin to halo comm

  INTEGER,ALLOCATABLE            :: SendRequest(:,:)         ! send request message handle,  1 - Number, 2-Message
  INTEGER,ALLOCATABLE            :: RecvRequest(:,:)         ! recv request message handle,  1 - Number, 2-Message

  INTEGER,ALLOCATABLE            :: nSurfDistSidesSend(:)    ! number of mpi sides to send (nProcs)
  INTEGER,ALLOCATABLE            :: nSurfDistSidesRecv(:)    ! number of sides received from mpi (nProcs)
  INTEGER,ALLOCATABLE            :: SurfDistSendRequest(:,:) ! send request message handle,  1 - Number, 2-Message
  INTEGER,ALLOCATABLE            :: SurfDistRecvRequest(:,:) ! recv request message handle,  1 - Number, 2-Message
  TYPE(tDistNbrComm),ALLOCATABLE :: NbrOfPos(:)              ! array for number of distribution sites sending per proc
END TYPE
TYPE (tSurfModelMPIExchange)          :: SurfModelExchange

#endif /*USE_MPI*/
!===================================================================================================================================

END MODULE MOD_SurfaceModel_MPI_Vars
