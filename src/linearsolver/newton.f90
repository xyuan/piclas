#include "boltzplatz.h"

MODULE MOD_Newton
!===================================================================================================================================
! Contains routines to compute the riemann (Advection, Diffusion) for a given Face
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------


#if (PP_TimeDiscMethod==104) 
INTERFACE Newton
  MODULE PROCEDURE Newton
END INTERFACE

!PUBLIC:: InitImplicit, FinalizeImplicit
PUBLIC:: Newton
#endif
!===================================================================================================================================

CONTAINS

#if (PP_TimeDiscMethod==104) 
!SUBROUTINE InitNewton()
!===================================================================================================================================
!! Allocate global variable 
!===================================================================================================================================
!! MODULES
!USE MOD_Globals
!USE MOD_PreProc
!USE MOD_Implicit_Vars
!USE MOD_Mesh_Vars,            ONLY:MeshInitIsDone
!USE MOD_Interpolation_Vars,   ONLY:InterpolationInitIsDone
!USE MOD_ReadInTools,          ONLY:GETINT,GETREAL,GETLOGICAL
!USE MOD_Precond,              ONLY:InitPrecond
!USE MOD_Predictor,            ONLY:InitPredictor
!! IMPLICIT VARIABLE HANDLING
!IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
!===================================================================================================================================
!IF((.NOT.InterpolationInitIsDone).OR.(.NOT.MeshInitIsDone).OR.ImplicitInitIsDone)THEN
!   CALL abort(__STAMP__,'InitImplicit not ready to be called or already called.',999,999.)
!END IF
!SWRITE(UNIT_StdOut,'(132("-"))')
!SWRITE(UNIT_stdOut,'(A)') ' INIT LINEAR SOLVER...'
!
!nGP2D=(PP_N+1)**2
!nGP3D=nGP2D*(PP_N+1)
!nDOFside=PP_nVar*nGP2D
!nDOFelem=PP_nVar*nGP3D
!nDofGlobal=nDOFelem*PP_nElems
!
!ALLOCATE(ImplicitSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems))
!ALLOCATE(LinSolverRHS  (1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems))
!!#if (PP_TimeDiscMethod==100)
!!  ALLOCATE(FieldSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1))
!!#endif
!!#if (PP_TimeDiscMethod==102)
!!  ALLOCATE(FieldSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:6))
!!#endif 
!
!#if (PP_TimeDiscMethod==104)
!!ALLOCATE(Q(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems)) LinSolverRHS
!! the time derivative computed at the actual Newton iteration value "xk"
!ALLOCATE(R_Xk(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems))
!ALLOCATE(Xk(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems))
!#endif
!
!nDofGlobalMPI=nDofGlobal
!#ifdef MPI
!  CALL MPI_ALLREDUCE(MPI_IN_PLACE,nDofGlobalMPI,1,MPI_INTEGER,MPI_SUM,MPI_COMM_WORLD,iError)
!#endif
!
!nRestarts             = GETINT('nRestarts','1')
!eps_LinearSolver      = GETREAL('eps_LinearSolver')
!epsTilde_LinearSolver = eps_LinearSolver!GETREAL('epsTilde_LinearSolver')
!eps2_LinearSolver     = eps_LinearSolver *eps_LinearSolver 
!maxIter_LinearSolver  = GETINT('maxIter_LinearSolver')
!
!nKDim=GETINT('nKDim','25')
!nInnerIter=0
!totalIterLinearSolver = 0
!
!ImplicitInitIsDone=.TRUE.
!SWRITE(UNIT_stdOut,'(A)')' INIT LINEAR SOLVER DONE!'
!! init predictor
!CALL InitPredictor()
!! init preconditoner
!CALL InitPrecond()
!END SUBROUTINE InitImplicit


SUBROUTINE Newton(t,alpha,beta)
!===================================================================================================================================
! Allocate global variable 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_DG_Vars,        ONLY: U,Ut
USE MOD_DG,             ONLY: DGTimeDerivative_wosource_weakForm
USE MOD_LinearSolver_vars,  ONLY: LinSolverRHS,Eps2Newton,nNewton, XK, R_XK, nDOFglobalMPI, nNewtonIter, gammaEW
USE MOD_Equation,       ONLY: CalcImplicitSource
USE MOD_TimeDisc_Vars,  ONLY: dt
USE MOD_LinearOperator, ONLY: VectorDotProduct
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)       :: t,alpha,beta
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
REAL                  :: time
INTEGER               :: iVar,i,j,k,iElem
INTEGER               :: nInnerNewton = 0
REAl                  :: coeff
REAL                  :: AbortCritLinSolver,gammaA,gammaB
REAL                  :: Norm2_F_X0,Norm2_F_Xk,Norm2_F_Xk_old
REAL                  :: F_X0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                  :: F_Xk(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                  :: DeltaX(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!===================================================================================================================================

time = t+beta*dt
coeff = alpha*dt
CALL DGTimeDerivative_woSource_weakForm(time,time,0)
CALL CalcImplicitSource(time,coeff,LinSolverRHS)

DO iElem=1,PP_nElems
  DO k=0,PP_N
    DO j=0,PP_N
      DO i=0,PP_N
        DO iVar=1,PP_nVar
          F_X0(iVar,i,j,k,iElem)=U(iVar,i,j,k,iElem)-LinSolverRHS(iVar,i,j,k,iElem)-Alpha*dt*Ut(iVar,i,j,k,iElem)  
          Xk(iVar,i,j,k,iElem)=U(iVar,i,j,k,iElem)
          R_Xk(iVar,i,j,k,iElem)=Ut(iVar,i,j,k,iElem)
          F_Xk(iVar,i,j,k,iElem)=F_X0(iVar,i,j,k,iElem)
        END DO
      END DO
    END DO
  END DO
END DO
CALL VectorDotProduct(F_X0,F_X0,Norm2_F_X0)
! Prepare stuff for matrix vector multiplication
IF(t.EQ.0)THEN
  IF (Norm2_F_X0.LE.(1.E-12)**2*nDOFglobalMPI) THEN ! do not iterate, as U is already the implicit solution
    Norm2_F_Xk=TINY(1.)
  ELSE ! we need iterations
    Norm2_F_Xk=Norm2_F_X0
  END IF
ELSE
  IF (Norm2_F_X0.LE.(1.E-8)**2*nDOFglobalMPI) THEN ! do not iterate, as U is already the implicit solution
    Norm2_F_Xk=TINY(1.)
  ELSE ! we need iterations
    Norm2_F_Xk=Norm2_F_X0
  END IF
END IF
nInnerNewton=0

DO WHILE((Norm2_F_Xk.GT.Eps2Newton*Norm2_F_X0).AND. (nInnerNewton.LT.nNewtonIter))
  IF (nInnerNewton.EQ.0) THEN
    AbortCritLinSolver=0.999
    Norm2_F_Xk_old=Norm2_F_Xk
  ELSE
    gammaA = gammaEW*(Norm2_F_Xk)/(Norm2_F_Xk_old)
    IF (gammaEW*AbortCritLinSolver*AbortCritLinSolver < 0.1) THEN
      gammaB = min(0.999,gammaA)
    ELSE
      gammaB = min(0.999, max(gammaA,gammaEW*AbortCritLinSolver*AbortCritLinSolver))
    ENDIF
    AbortCritLinSolver = min(0.999,max(gammaB,0.5*SQRT(Eps2Newton)/SQRT(Norm2_F_Xk)))
    Norm2_F_Xk_old=Norm2_F_Xk
  END IF 
  nInnerNewton=nInnerNewton+1
  !
  CALL GMRES_M_DX(t,Alpha,Beta,-F_Xk,SQRT(Norm2_F_Xk),AbortCritLinSolver,DeltaX)
  DO iElem=1,PP_nElems
    DO k=0,PP_N
      DO j=0,PP_N
        DO i=0,PP_N
          DO iVar=1,PP_nVar
            Xk(iVar,i,j,k,iElem)=Xk(iVar,i,j,k,iElem)+DeltaX(iVar,i,j,k,iElem)
            U(iVar,i,j,k,iElem)=Xk(iVar,i,j,k,iElem)
          END DO
        END DO
      END DO
    END DO
  END DO
  CALL DGTimeDerivative_WoSource_weakForm(Time,Time,0)
  DO iElem=1,PP_nElems
    DO k=0,PP_N
      DO j=0,PP_N
        DO i=0,PP_N
          DO iVar=1,PP_nVar
            R_Xk(iVar,i,j,k,iElem)=Ut(iVar,i,j,k,iElem)
            F_Xk(iVar,i,j,k,iElem)=U(iVar,i,j,k,iElem)-LinSolverRHS(iVar,i,j,k,iElem)-alpha*dt*Ut(iVar,i,j,k,iElem)
          END DO
        END DO
      END DO
    END DO
  END DO
  CALL VectorDotProduct(F_Xk,F_Xk,Norm2_F_Xk)
END DO
nNewton=nNewton+nInnerNewton
IF (nInnerNewton.EQ.nNewtonIter) THEN
  WRITE(*,*) Eps2Newton
  CALL abort(__STAMP__, &
  'NEWTON NOT CONVERGED WITH NEWTON ITERATIONS AND RESIDUAL REDUCTION F_Xk/F_X0:',nInnerNewton,Norm2_F_Xk/Norm2_F_X0)
END IF

END SUBROUTINE Newton

!SUBROUTINE LinearSolver_BiCGStab(t,Coeff)
!===================================================================================================================================
!! Solves Linear system Ax=b using BiCGStab with right preconditioner P_r
!! Matrix A = I - Coeff*R
!! Attention: Vector x is U^n+1, initial guess set to U^n 
!! Attention: Vector b is U^n 
!===================================================================================================================================
!! MODULES
!USE MOD_PreProc
!USE MOD_Globals
!USE MOD_DG_Vars,       ONLY: U
!USE MOD_TimeDisc_Vars, ONLY: dt
!USE MOD_Precond_Vars,  ONLY: PrecondType
!USE MOD_Precond,       ONLY: ApplyPrecond_Elem,ApplyPrecond_DOF,ApplyPrecond_GMRES,ApplyPrecond_Jacobi
!USE MOD_Implicit_Vars, ONLY: eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
!USE MOD_Implicit_Vars, ONLY: LinSolverRHS,ImplicitSource,nRestarts
!USE MOD_LinearOperator, ONLY: MatrixVector, MatrixVectorSource, VectorDotProduct
!USE MOD_SparseILU,        ONLY: ApplyILU
!! IMPLICIT VARIABLE HANDLING
!IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!! INPUT VARIABLES
!REAL,INTENT(IN)  :: t,Coeff
!-----------------------------------------------------------------------------------------------------------------------------------
!! LOCAL VARIABLES
!REAL             :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: S(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: TVec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: Norm_R0,Norm_R,Norm_T2
!INTEGER          :: iterLinSolver,Restart
!REAL             :: alpha,sigma,omega,beta
!REAL             :: AbortCrit
!! preconditioner
!REAL             :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!REAL             :: St(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!#ifdef DLINANALYZE
!REAL             :: tS,tE,tStart,tend
!REAL             :: tDG, tPrecond
!#endif /* DLINANALYZE */
!===================================================================================================================================
!
!! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
!! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!!       A                x   = b
!! 
!! Residuum
!! for initial guess, x0 is set to U^n
!! R0 = b - A x0
!!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!!    = dt*Source^n+1  + dt*DG_Operator U^n 
!!    = dt*Ut + dt*Source^n+1
!
!#ifdef DLINANALYZE
!tPrecond=0.
!tDG=0.
!CALL CPU_TIME(tS)
!#endif /* DLINANALYZE */
!
!! store here for later use
!Un   = U ! here, n stands for U^n
!Uold = U
!Restart=0
!nInnerIter = 0
!! LinSolverRHS and X0 = U
!CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
!! compute  A*U^n
!CALL VectorDotProduct(R0,R0,Norm_R0)
!
!alpha=Norm_R0
!Norm_R0=SQRT(Norm_R0)
!
!P  = R0
!R  = R0
!AbortCrit = Norm_R0*eps_LinearSolver
!
!DO WHILE (Restart.LT.nRestarts)  ! maximum of two trials with BiCGStab inner interation
!  DO iterLinSolver = 1, maxIter_LinearSolver  ! two trials with half of iterations
!    ! Preconditioner
!#ifdef DLINANALYZE
!        CALL CPU_TIME(tStart)
!#endif /* DLINANALYZE */
!    SELECT CASE(PrecondType)
!      CASE(1,2) ! Finite-Differences and analytical Preconditioner
!        ! BJ per Element
!        CALL ApplyPrecond_Elem(P,Pt)
!      CASE(3) 
!        ! BJ per DOF, only analytic
!        CALL ApplyPrecond_DOF(P,Pt)
!      CASE(4)
!        ! iterative through 
!        CALL ApplyPrecond_GMRES(coeff,P,Pt)
!      CASE(5,6,7,8,9,10,11)
!        ! Jaboci Preconditioner 
!        CALL ApplyPrecond_Jacobi(P,Pt)
!      CASE(22)
!        CALL ApplyILU(P,Pt)
!      CASE(30)
!      CASE(31)
!      CASE DEFAULT
!        Pt=P
!    END SELECT
!#ifdef DLINANALYZE
!    CALL CPU_TIME(tend)
!    tPrecond=tPrecond+tend-tStart
!    ! matrix vector
!    CALL CPU_TIME(tStart)
!#endif /* DLINANALYZE */
!    CALL MatrixVector(t,coeff,Pt,V)
!#ifdef DLINANALYZE
!    CALL CPU_TIME(tend)
!    tDG=tDG+tend-tStart
!#endif /* DLINANALYZE */
!    CALL VectorDotProduct(V,R0,sigma)
!    !CALL VectorDotProduct(R,R0,alpha)
!
!    alpha=alpha/sigma
!    S = R - alpha*V
!
!#ifdef DLINANALYZE
!    CALL CPU_TIME(tStart)
!#endif /* DLINANALYZE */
!    ! Preconditioner
!    SELECT CASE(PrecondType)
!      CASE(1,2) ! Finite-Differences and analytical Preconditioner
!        ! BJ per Element
!        CALL ApplyPrecond_Elem(S,St)
!      CASE(3) 
!        ! BJ per DOF, only analytic
!        CALL ApplyPrecond_DOF(S,St)
!      CASE(4)
!        ! iterative through 
!        CALL ApplyPrecond_GMRES(coeff,S,St)
!      CASE(5,6,7,8,9,10,11)
!        ! Jaboci Preconditioner 
!        CALL ApplyPrecond_Jacobi(S,St)
!      CASE(22)
!        CALL ApplyILU(S,St)
!      CASE(30)
!      CASE(31)
!      CASE DEFAULT
!        St=S
!    END SELECT
!#ifdef DLINANALYZE
!    CALL CPU_TIME(tend)
!    tPrecond=tPrecond+tend-tStart
!    CALL CPU_TIME(tStart)
!#endif /* DLINANALYZE */
!    ! matrix vector
!    CALL MatrixVector(t,coeff,St,TVec)
!#ifdef DLINANALYZE
!    CALL CPU_TIME(tend)
!    tDG=tDG+tend-tStart
!#endif /* DLINANALYZE */
!
!    CALL VectorDotProduct(TVec,TVec,Norm_T2)
!    CALL VectorDotProduct(TVec,S,omega)
!    omega=omega/Norm_T2
!
!    Un=Un+alpha*Pt+omega*St
!    R=S-omega*TVec
!    CALL VectorDotProduct(R,R0,alpha)
!    beta=alpha/(omega*sigma)
!    P=R+beta*(P-omega*V)
!    CALL VectorDotProduct(R,R,Norm_R)
!    Norm_R=SQRT(Norm_R)
!    ! test if success
!    IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
!      U=Un
!      nInnerIter=nInnerIter+iterLinSolver
!      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
!#ifdef DLINANALYZE
!      CALL CPU_TIME(tE)
!      ! Debug Ausgabe, Anzahl der Iterationen...
!      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
!      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
!      SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in BiCGSTAB   : ',tE-tS
!      SWRITE(UNIT_stdOut,'(A23,E16.8)')   ' Norm_R0            : ',Norm_R0
!      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
!      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
!#endif /* DLINANALYZE */
!      RETURN
!    ENDIF
!  END DO ! iterLinSolver
!  ! restart with new U
!  ! LinSolverRHS and X0 = U
!!  U              = 0.5*(Uold+Un)
!  ImplicitSource = 0.
!  U             = Un
!  ! LinSolverRHS and X0 = U
!  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
!  ! compute  A*U^n
!  CALL VectorDotProduct(R0,R0,Norm_R0)
!  alpha=Norm_R0
!  Norm_R0=SQRT(Norm_R0)
!  P  = R0
!  R  = R0
!  nInnerIter=nInnerIter+iterLinSolver
!  Restart = Restart + 1
!END DO ! while chance < 2 
!
!SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
!SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
!CALL abort(__STAMP__, &
!     'BiCGSTAB NOT CONVERGED WITH RESTARTS AND GMRES ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))
!
!END SUBROUTINE LinearSolver_BiCGSTAB

SUBROUTINE GMRES_M_DX(t,Alpha,Beta,B,Norm_B,AbortCrit,DeltaX)
!===================================================================================================================================
! Uses matrix free to solve the linear system
! Attention: We use DeltaX=0 as our initial guess   ! why not Un??
!            X0 is allready stored in U
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,          ONLY: U
USE MOD_Precond,          ONLY: ApplyPrecond_Elem,ApplyPrecond_DOF,ApplyPrecond_GMRES, ApplyPrecond_Jacobi
USE MOD_Precond_Vars,     ONLY: PrecondType
USE MOD_LinearSolver_Vars,    ONLY: LinSolverRHS,ImplicitSource
USE MOD_LinearSolver_Vars,    ONLY: eps_LinearSolver,TotalIterLinearSolver
USE MOD_LinearSolver_Vars,    ONLY: nKDim,nRestarts,nInnerIter,EisenstatWalker
USE MOD_LinearOperator,   ONLY: MatrixVector, VectorDotProduct
USE MOD_SparseILU,        ONLY: ApplyILU
USE MOD_TimeDisc_Vars,    ONLY: dt
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)   :: t,Alpha,Beta,Norm_B
REAL,INTENT(IN)   :: B(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL,INTENT(INOUT):: AbortCrit
REAL,INTENT(OUT)  :: DeltaX(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL              :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL              :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:nKDim)
REAL              :: V2P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL              :: W(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL              :: Z(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL              :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL              :: Gam(1:nKDim+1),C(1:nKDim),S(1:nKDim),H(1:nKDim+1,1:nKDim+1),Alp(1:nKDim+1)
REAL              :: Norm_R0,Resu,Temp,Bet
REAL              :: coeff
INTEGER           :: Restart
INTEGER           :: m,nn,o
! preconditoner + Vt
REAL              :: Vt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:nKDim)
REAL              :: Vt2(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
#ifdef DLINANALYZE
REAL              :: tS,tE, tS2,tE2,t1,t2
real              :: tstart,tend,tPrecond,tDG
#endif /* DLINANALYZE */
!===================================================================================================================================

#ifdef DLINANALYZE
! time measurement
CALL CPU_TIME(tS)
! start GMRES
tPrecond=0.
tDG=0.
#endif /* DLINANALYZE */

Restart=0
nInnerIter=0
Un=U 
coeff= alpha*dt
IF(t.EQ.0) THEN
  AbortCrit=eps_LinearSolver
ELSE
  IF (EisenstatWalker .eqv. .FALSE.) THEN
    AbortCrit=eps_LinearSolver
  END IF
END IF
AbortCrit=Norm_B*AbortCrit
R0=B
Norm_R0=Norm_B
DeltaX=0.

V(:,:,:,:,:,1)=R0/Norm_R0
Gam(1)=Norm_R0

DO WHILE (Restart<nRestarts)
  DO m=1,nKDim
    nInnerIter=nInnerIter+1
    ! Preconditioner
#ifdef DLINANALYZE
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    SELECT CASE(PrecondType)
      CASE(1,2) ! Finite-Differences and analytical Preconditioner
        ! BJ per Element
        CALL ApplyPrecond_Elem(V(:,:,:,:,:,m),Vt(:,:,:,:,:,m))
      CASE(3) 
        ! BJ per DOF, only analytic, nVar x nVar
        CALL ApplyPrecond_Elem(V(:,:,:,:,:,m),Vt(:,:,:,:,:,m))
      CASE(22)
        ! ILU(0)
        CALL ApplyILU(V(:,:,:,:,:,m),Vt(:,:,:,:,:,m))
      CASE(30)
        ! LU-SGS
      CASE(31)
        ! Element Block LU-SGS
      CASE DEFAULT
        Vt(:,:,:,:,:,m)=V(:,:,:,:,:,m)
    END SELECT
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tPrecond=tPrecond+tend-tStart
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    ! matrix vector
    CALL MatrixVector(t,coeff,Vt(:,:,:,:,:,m),W)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tDG=tDG+tend-tStart
#endif /* DLINANALYZE */
    ! Gram-Schmidt
    DO nn=1,m
      CALL VectorDotProduct(V(:,:,:,:,:,nn),W,H(nn,m))
      W=W-H(nn,m)*V(:,:,:,:,:,nn)
    END DO !nn
    CALL VectorDotProduct(W,W,Resu)
    H(m+1,m)=SQRT(Resu)
    ! Givens Rotation
    DO nn=1,m-1
      Temp     =   C(nn)*H(nn,m) + S(nn)*H(nn+1,m)
      H(nn+1,m) = - S(nn)*H(nn,m) + C(nn)*H(nn+1,m)
      H(nn,m)   =   Temp
    END DO !nn
    Bet=SQRT(H(m,m)*H(m,m)+H(m+1,m)*H(m+1,m))
    S(m)=H(m+1,m)/Bet
    C(m)=H(m,m)/Bet 
    H(m,m)=Bet
    Gam(m+1)=-S(m)*Gam(m)
    Gam(m)=C(m)*Gam(m)
    IF ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim)) THEN !converge or max Krylov reached
      DO nn=m,1,-1
         Alp(nn)=Gam(nn) 
         DO o=nn+1,m
           Alp(nn)=Alp(nn) - H(nn,o)*Alp(o)
         END DO !o
         Alp(nn)=Alp(nn)/H(nn,nn)
      END DO !nn
      DO nn=1,m
        DeltaX=DeltaX+Alp(nn)*Vt(:,:,:,:,:,nn)
      END DO !nn
      IF (ABS(Gam(m+1)).LE.AbortCrit) THEN !converged
        totalIterLinearSolver=totalIterLinearSolver+nInnerIter
        ! already back transformed,...more storage...but its ok
#ifdef DLINANALYZE
        CALL CPU_TIME(tE)
        SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
        SWRITE(UNIT_stdOut,'(A22,I5)')      ' nRestarts          : ',Restart
        SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in GMRES      : ',tE-tS
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Gam(1)
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Gam(m+1)
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
        RETURN
      END IF  ! converged
    ELSE ! no convergence, next iteration   ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim)) 
      V(:,:,:,:,:,m+1)=W/H(m+1,m)
    END IF ! ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim))
  END DO ! m 
  ! Restart needed
  Restart=Restart+1
  ! new settings for source
  !U=DeltaX
! start residuum berrechnen
  CALL MatrixVector(t,Coeff,DeltaX,R0) ! coeff*Ut+Source^n+1 ! only output
  R0=B-R0
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
  ! GMRES(m)  inner loop
  V(:,:,:,:,:,1)=R0/Norm_R0
  Gam(1)=Norm_R0
END DO ! Restart

CALL abort(__STAMP__, &
     'GMRES_M NOT CONVERGED WITH RESTARTS AND GMRES ITERATIONS:',Restart,REAL(nInnerIter))

END SUBROUTINE GMRES_M_DX

!SUBROUTINE FinalizeImplicit()
!===================================================================================================================================
!! Deallocate global variable U (solution) and Ut (dg time derivative).
!===================================================================================================================================
!! MODULES
!USE MOD_Implicit_Vars,ONLY:ImplicitInitIsDone,ImplicitSource,LinSolverRHS
!USE MOD_Predictor    ,ONLY:FinalizePredictor
!! IMPLICIT VARIABLE HANDLING
!IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
!===================================================================================================================================
!
!ImplicitInitIsDone = .FALSE.
!SDEALLOCATE(ImplicitSource)
!SDEALLOCATE(LinSolverRHS)
!CALL FinalizePredictor
!!SDEALLOCATE(FieldSource)
!END SUBROUTINE FinalizeImplicit

#endif

END MODULE MOD_Newton