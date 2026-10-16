/*
=====================================================================
34. KHOI PHUC QUYEN ADMIN VA KIEM TRA NGU CANH BENH NHAN
- quan_tri_cskcb la superuser trong CHINH CSKCB cua tai khoan.
- Bo sung/quay lai day du quyen cho tat ca chuc nang active.
- Khong doi IDCSKCB cua tai khoan va khong truy cap cheo CSKCB.
- Khong in dump bang du lieu khi chay updater; chi khoi phuc quyen admin.
=====================================================================
*/
USE [QLPM];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @IDCSKCB BIGINT;

DECLARE cs CURSOR LOCAL FAST_FORWARD FOR
SELECT ID FROM dbo.DM_CSKCB WHERE Active=1;

OPEN cs;
FETCH NEXT FROM cs INTO @IDCSKCB;

WHILE @@FETCH_STATUS=0
BEGIN
    INSERT dbo.HT_Quyen_Vai_Tro
    (
        IDCSKCB,ID_Vai_Tro,ID_Chuc_Nang,
        Xem,Them,Sua,Xoa,Xuat,Ca_Nhan
    )
    SELECT
        @IDCSKCB,VT.ID,CN.ID,
        1,1,1,1,1,1
    FROM dbo.DM_Vai_Tro VT
    CROSS JOIN dbo.HT_Chuc_Nang CN
    WHERE VT.IDCSKCB=@IDCSKCB
      AND VT.Ma_Vai_Tro=N'quan_tri_cskcb'
      AND VT.Active=1
      AND CN.IDCSKCB=@IDCSKCB
      AND CN.Active=1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.HT_Quyen_Vai_Tro Q
          WHERE Q.IDCSKCB=@IDCSKCB
            AND Q.ID_Vai_Tro=VT.ID
            AND Q.ID_Chuc_Nang=CN.ID
      );

    UPDATE Q
    SET Xem=1,Them=1,Sua=1,Xoa=1,Xuat=1,Ca_Nhan=1
    FROM dbo.HT_Quyen_Vai_Tro Q
    INNER JOIN dbo.DM_Vai_Tro VT
      ON VT.IDCSKCB=Q.IDCSKCB
     AND VT.ID=Q.ID_Vai_Tro
     AND VT.Ma_Vai_Tro=N'quan_tri_cskcb'
     AND VT.Active=1
    INNER JOIN dbo.HT_Chuc_Nang CN
      ON CN.IDCSKCB=Q.IDCSKCB
     AND CN.ID=Q.ID_Chuc_Nang
     AND CN.Active=1
    WHERE Q.IDCSKCB=@IDCSKCB;

    FETCH NEXT FROM cs INTO @IDCSKCB;
END;

CLOSE cs;
DEALLOCATE cs;
GO

SELECT N'34_khoi_phuc_quyen_admin_va_ngu_canh_benh_nhan.sql hoan tat.' AS Message;
GO
