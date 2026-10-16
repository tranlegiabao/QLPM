using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using QuanLyPhongMach.Entities;

namespace QuanLyPhongMach.Data;

public partial class QlpmDbContext : DbContext
{
    public QlpmDbContext()
    {
    }

    public QlpmDbContext(DbContextOptions<QlpmDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<DmCskcb> DmCskcb { get; set; }

    public virtual DbSet<DmChucDanh> DmChucDanh { get; set; }

    public virtual DbSet<DmDanToc> DmDanToc { get; set; }

    public virtual DbSet<DmDichVu> DmDichVu { get; set; }

    public virtual DbSet<DmDonViTinh> DmDonViTinh { get; set; }

    public virtual DbSet<DmIcd10> DmIcd10 { get; set; }

    public virtual DbSet<DmLoaiToaThuoc> DmLoaiToaThuoc { get; set; }

    public virtual DbSet<DmGioiTinh> DmGioiTinh { get; set; }

    public virtual DbSet<DmNganHang> DmNganHang { get; set; }

    public virtual DbSet<DmNhanVien> DmNhanVien { get; set; }

    public virtual DbSet<DmNhanVienCskcb> DmNhanVienCskcb { get; set; }

    public virtual DbSet<DmNhomHang> DmNhomHang { get; set; }

    public virtual DbSet<DmPhacDo> DmPhacDo { get; set; }

    public virtual DbSet<DmPhacDoChiDinh> DmPhacDoChiDinh { get; set; }

    public virtual DbSet<DmPhacDoThuoc> DmPhacDoThuoc { get; set; }

    public virtual DbSet<DmPhuongXa> DmPhuongXa { get; set; }

    public virtual DbSet<DmThuoc> DmThuoc { get; set; }

    public virtual DbSet<DmTinhThanh> DmTinhThanh { get; set; }

    public virtual DbSet<DmTriSoSinhHieu> DmTriSoSinhHieu { get; set; }

    public virtual DbSet<QlBenhNhan> QlBenhNhan { get; set; }

    public virtual DbSet<QlChanDoanCt> QlChanDoanCt { get; set; }

    public virtual DbSet<QlChiDinhCt> QlChiDinhCt { get; set; }

    public virtual DbSet<QlCongKham> QlCongKham { get; set; }

    public virtual DbSet<QlCongKhamCt> QlCongKhamCt { get; set; }

    public virtual DbSet<QlPhieuSinhHieu> QlPhieuSinhHieu { get; set; }

    public virtual DbSet<QlPhieuSinhHieuCt> QlPhieuSinhHieuCt { get; set; }

    public virtual DbSet<QlThuTien> QlThuTien { get; set; }

    public virtual DbSet<QlThuTienCt> QlThuTienCt { get; set; }

    public virtual DbSet<QlToaThuocCt> QlToaThuocCt { get; set; }

    public virtual DbSet<QlToaThuoc> QlToaThuoc { get; set; }

    public virtual DbSet<QlToaThuocPhienBan> QlToaThuocPhienBan { get; set; }

    public virtual DbSet<QlToaThuocLanGui> QlToaThuocLanGui { get; set; }

    public virtual DbSet<QlToaThuocAudit> QlToaThuocAudit { get; set; }

    public virtual DbSet<HtLienThongToaThuocCauHinh> HtLienThongToaThuocCauHinh { get; set; }

    public virtual DbSet<HtLienThongToaThuocBacSi> HtLienThongToaThuocBacSi { get; set; }

    public virtual DbSet<QlVaoVien> QlVaoVien { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            optionsBuilder.UseSqlServer("Name=ConnectionStrings:QLPM");
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<DmCskcb>(entity =>
        {
            // SQL Server DM_CSKCB has enabled triggers; EF Core 7 must avoid DML OUTPUT without INTO.
            // HasTrigger is EF metadata and does not create, rename or disable the database trigger.
            entity.ToTable("DM_CSKCB", t => t.HasTrigger("TR_DM_CSKCB"));

            entity.HasIndex(e => e.MaCskcb, "UQ_DM_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DiaChi).HasMaxLength(500);
            entity.Property(e => e.SoNhaTenDuong).HasMaxLength(300);
            entity.Property(e => e.Email).HasMaxLength(200);
            entity.Property(e => e.IdnganHang).HasColumnName("IDNganHang");
            entity.Property(e => e.MaCskcb)
                .HasMaxLength(20)
                .HasColumnName("MaCSKCB");
            entity.Property(e => e.MaSt)
                .HasMaxLength(50)
                .HasColumnName("MaST");
            entity.Property(e => e.MaTinh).HasMaxLength(20);
            entity.Property(e => e.MaPhuongXa).HasMaxLength(20);
            entity.Property(e => e.Sdt)
                .HasMaxLength(100)
                .HasColumnName("SDT");
            entity.Property(e => e.SoTk)
                .HasMaxLength(100)
                .HasColumnName("SoTK");
            entity.Property(e => e.TenCskcb)
                .HasMaxLength(300)
                .HasColumnName("TenCSKCB");
            entity.Property(e => e.UrlLogo).HasMaxLength(1000);

            entity.HasOne(d => d.IdnganHangNavigation).WithMany(p => p.DmCskcb)
                .HasForeignKey(d => d.IdnganHang)
                .HasConstraintName("FK_DM_CSKCB_NganHang");
        });

        modelBuilder.Entity<DmChucDanh>(entity =>
        {
            entity.ToTable("DM_ChucDanh");
            entity.HasIndex(e => e.MaChucDanh, "UQ_DM_ChucDanh_Ma").IsUnique();
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.MaChucDanh).HasMaxLength(60);
            entity.Property(e => e.TenChucDanh).HasMaxLength(200);
            entity.Property(e => e.VietTat).HasMaxLength(50);
            entity.Property(e => e.Active).HasDefaultValue(true);
        });

        modelBuilder.Entity<DmDanToc>(entity =>
        {
            entity.ToTable("DM_DanToc");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_DanToc_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaDanToc }, "UQ_DM_DanToc_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.MaDanToc).HasMaxLength(20);
            entity.Property(e => e.TenDanToc).HasMaxLength(200);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmDanToc)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_DanToc_CSKCB");
        });

        modelBuilder.Entity<DmDonViTinh>(entity =>
        {
            entity.ToTable("DM_DonViTinh");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_DonViTinh_CSKCB_ID").IsUnique();
            entity.HasIndex(e => new { e.Idcskcb, e.MaDvt }, "UQ_DM_DonViTinh_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaDvt).HasMaxLength(100).HasColumnName("MaDVT");
            entity.Property(e => e.TenDvt).HasMaxLength(1000).HasColumnName("TenDVT");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmDonViTinh)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_DonViTinh_CSKCB");
        });

        modelBuilder.Entity<DmDichVu>(entity =>
        {
            entity.ToTable("DM_DichVu");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_DichVu_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaDichVu }, "UQ_DM_DichVu_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.DonViTinh).HasMaxLength(50);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaDichVu).HasMaxLength(30);
            entity.Property(e => e.TenDichVu).HasMaxLength(300);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmDichVu)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_DichVu_CSKCB");
        });

        modelBuilder.Entity<DmIcd10>(entity =>
        {
            entity.ToTable("DM_ICD10");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_ICD10_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaBenh }, "UQ_DM_ICD10_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaBenh).HasMaxLength(20);
            entity.Property(e => e.TenBenh).HasMaxLength(500);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmIcd10)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_ICD10_CSKCB");
        });

        modelBuilder.Entity<DmGioiTinh>(entity =>
        {
            entity.ToTable("DM_GioiTinh");

            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.MaGioiTinh, "UQ_DM_GioiTinh_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID").ValueGeneratedNever();
            entity.Property(e => e.MaGioiTinh).HasMaxLength(10);
            entity.Property(e => e.TenGioiTinh).HasMaxLength(50);
            entity.Property(e => e.ThuTu).HasDefaultValue(999);
            entity.Property(e => e.Active).HasDefaultValue(true);
        });

        modelBuilder.Entity<DmNganHang>(entity =>
        {
            entity.ToTable("DM_NganHang");

            entity.HasIndex(e => e.MaNganHang, "UQ_DM_NganHang_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.MaNganHang).HasMaxLength(50);
            entity.Property(e => e.TenNganHang).HasMaxLength(300);
        });

        modelBuilder.Entity<DmNhanVien>(entity =>
        {
            entity.ToTable("DM_NhanVien");

            entity.HasIndex(e => e.MaNhanVien, "IX_DM_NhanVien_MaNhanVien");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.IdchucDanh).HasColumnName("IDChucDanh");
            entity.Property(e => e.DienThoai).HasMaxLength(20);
            entity.Property(e => e.SoNhaTenDuong).HasMaxLength(300);
            entity.Property(e => e.DiaChi).HasMaxLength(500);
            entity.Property(e => e.Email).HasMaxLength(200);
            entity.Property(e => e.HoTen).HasMaxLength(200);
            entity.Property(e => e.MaNhanVien).HasMaxLength(30);
            entity.Property(e => e.MaTinh).HasMaxLength(20);
            entity.Property(e => e.MaPhuongXa).HasMaxLength(20);

            entity.HasOne(d => d.IdchucDanhNavigation).WithMany(p => p.DmNhanVien)
                .HasForeignKey(d => d.IdchucDanh)
                .HasConstraintName("FK_DM_NhanVien_ChucDanh");
        });

        modelBuilder.Entity<DmNhanVienCskcb>(entity =>
        {
            entity.ToTable("DM_NhanVien_CSKCB");
            entity.HasKey(e => new { e.IdnhanVien, e.Idcskcb });
            entity.Property(e => e.IdnhanVien).HasColumnName("IDNhanVien");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.Active).HasDefaultValue(true);

            entity.HasOne(d => d.IdnhanVienNavigation).WithMany(p => p.DmNhanVienCskcb)
                .HasForeignKey(d => d.IdnhanVien)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("FK_DM_NhanVien_CSKCB_NhanVien");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmNhanVienCskcb)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("FK_DM_NhanVien_CSKCB_CSKCB");
        });

        modelBuilder.Entity<DmPhacDo>(entity =>
        {
            entity.ToTable("DM_PhacDo");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_PhacDo_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaPhacDo }, "UQ_DM_PhacDo_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaPhacDo).HasMaxLength(30);
            entity.Property(e => e.TenPhacDo).HasMaxLength(300);
            entity.Property(e => e.TrieuChung).HasMaxLength(2000);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmPhacDo)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_PhacDo_CSKCB");
        });

        modelBuilder.Entity<DmPhacDoChiDinh>(entity =>
        {
            entity.ToTable("DM_PhacDo_ChiDinh");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IddichVu).HasColumnName("IDDichVu");
            entity.Property(e => e.IdphacDo).HasColumnName("IDPhacDo");
            entity.Property(e => e.NoiGuiNgoai).HasMaxLength(300);
            entity.Property(e => e.SoLuong)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(10, 2)");

            entity.HasOne(d => d.IddichVuNavigation).WithMany(p => p.DmPhacDoChiDinh)
                .HasForeignKey(d => d.IddichVu)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_PhacDo_CD_DichVu");

            entity.HasOne(d => d.IdphacDoNavigation).WithMany(p => p.DmPhacDoChiDinh)
                .HasForeignKey(d => d.IdphacDo)
                .HasConstraintName("FK_DM_PhacDo_CD_PhacDo");
        });

        modelBuilder.Entity<DmPhacDoThuoc>(entity =>
        {
            entity.ToTable("DM_PhacDo_Thuoc");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.CachDung).HasMaxLength(500);
            entity.Property(e => e.Chieu).HasMaxLength(50);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.DuongDung).HasMaxLength(100);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdphacDo).HasColumnName("IDPhacDo");
            entity.Property(e => e.Idthuoc).HasColumnName("IDThuoc");
            entity.Property(e => e.IddonViTinhDung).HasColumnName("IDDonViTinhDung");
            entity.Property(e => e.LieuDung).HasMaxLength(300);
            entity.Property(e => e.Sang).HasMaxLength(50);
            entity.Property(e => e.SoLuong)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(10, 2)");
            entity.Property(e => e.SoNgay).HasDefaultValue(3);
            entity.Property(e => e.Toi).HasMaxLength(50);
            entity.Property(e => e.Trua).HasMaxLength(50);

            entity.HasOne(d => d.IdphacDoNavigation).WithMany(p => p.DmPhacDoThuoc)
                .HasForeignKey(d => d.IdphacDo)
                .HasConstraintName("FK_DM_PhacDo_Thuoc_PhacDo");

            entity.HasOne(d => d.IdthuocNavigation).WithMany(p => p.DmPhacDoThuoc)
                .HasForeignKey(d => d.Idthuoc)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_PhacDo_Thuoc_Thuoc");
        });

        modelBuilder.Entity<DmPhuongXa>(entity =>
        {
            entity.ToTable("DM_PhuongXa");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_PhuongXa_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaPhuongXa }, "UQ_DM_PhuongXa_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdtinhThanh).HasColumnName("IDTinhThanh");
            entity.Property(e => e.MaPhuongXa).HasMaxLength(20);
            entity.Property(e => e.TenPhuongXa).HasMaxLength(200);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmPhuongXa)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_PhuongXa_CSKCB");

            entity.HasOne(d => d.DmTinhThanh).WithMany(p => p.DmPhuongXa)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtinhThanh })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_PhuongXa_Tinh");
        });

        modelBuilder.Entity<DmThuoc>(entity =>
        {
            entity.ToTable("DM_Thuoc");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_Thuoc_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaThuoc }, "UQ_DM_Thuoc_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonViTinh).HasMaxLength(100);
            entity.Property(e => e.DuongDung).HasMaxLength(200);
            entity.Property(e => e.GiaBan).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.HamLuong).HasMaxLength(300);
            entity.Property(e => e.HoatChat).HasMaxLength(500);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IddonViTinh).HasColumnName("IDDonViTinh");
            entity.Property(e => e.IdnhomHang).HasColumnName("IDNhomHang");
            entity.Property(e => e.MaThuoc).HasMaxLength(50);
            entity.Property(e => e.MaThuocQuocGia).HasMaxLength(20);
            entity.Property(e => e.TenThuoc).HasMaxLength(500);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmThuoc)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_Thuoc_CSKCB");

            entity.HasOne(d => d.IddonViTinhNavigation).WithMany(p => p.DmThuoc)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IddonViTinh })
                .HasConstraintName("FK_DM_Thuoc_DonViTinh");

            entity.HasOne(d => d.DmNhomHang).WithMany(p => p.DmThuoc)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdnhomHang })
                .HasConstraintName("FK_DM_Thuoc_NhomHang");
        });

        modelBuilder.Entity<DmLoaiToaThuoc>(entity =>
        {
            entity.ToTable("DM_LoaiToaThuoc");

            entity.HasKey(e => e.MaLoaiToaThuoc);
            entity.Property(e => e.MaLoaiToaThuoc).HasMaxLength(1).HasColumnName("MaLoaiToaThuoc");
            entity.Property(e => e.TenLoaiToaThuoc).HasMaxLength(500).HasColumnName("TenLoaiToaThuoc").IsRequired();
            entity.Property(e => e.Active).HasDefaultValue(true);
        });

        modelBuilder.Entity<DmNhomHang>(entity =>
        {
            entity.ToTable("DM_NhomHang");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_NhomHang_CSKCB_ID").IsUnique();
            entity.HasIndex(e => new { e.Idcskcb, e.MaNhomHang }, "UQ_DM_NhomHang_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaNhomHang).HasMaxLength(50).IsRequired();
            entity.Property(e => e.TenNhomHang).HasMaxLength(200).IsRequired();
            entity.Property(e => e.MaLoaiToaThuoc).HasMaxLength(1).HasColumnName("MaLoaiToaThuoc");
            entity.Property(e => e.Active).HasDefaultValue(true);

            entity.HasOne(d => d.DmLoaiToaThuoc).WithMany(p => p.DmNhomHang)
                .HasForeignKey(d => d.MaLoaiToaThuoc)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_NhomHang_LoaiToaThuoc");
        });

        modelBuilder.Entity<DmTinhThanh>(entity =>
        {
            entity.ToTable("DM_TinhThanh");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_TinhThanh_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaTinh }, "UQ_DM_TinhThanh_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaTinh).HasMaxLength(20);
            entity.Property(e => e.TenTinh).HasMaxLength(200);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmTinhThanh)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_TinhThanh_CSKCB");
        });

        modelBuilder.Entity<DmTriSoSinhHieu>(entity =>
        {
            entity.ToTable("DM_TriSoSinhHieu");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_DM_TriSoSinhHieu_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaTriSo }, "UQ_DM_TriSoSinhHieu_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonViTinh).HasMaxLength(50);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.MaTriSo).HasMaxLength(30);
            entity.Property(e => e.TenTriSo).HasMaxLength(100);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.DmTriSoSinhHieu)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DM_TriSoSinhHieu_CSKCB");
        });

        modelBuilder.Entity<QlBenhNhan>(entity =>
        {
            entity.ToTable("QL_BenhNhan", t => t.HasTrigger("TR_QL_BenhNhan_KyPdf"));

            entity.HasIndex(e => new { e.Idcskcb, e.HoTen, e.DienThoai, e.SoCccd }, "IX_QL_BenhNhan_Tim");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_BenhNhan_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaBn }, "UQ_QL_BenhNhan_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DiaChi).HasMaxLength(500);
            entity.Property(e => e.DienThoai).HasMaxLength(50);
            entity.Property(e => e.GhiChu).HasMaxLength(1000);
            entity.Property(e => e.GiamHoDienThoai)
                .HasMaxLength(50)
                .HasColumnName("GiamHo_DienThoai");
            entity.Property(e => e.GiamHoHoTen)
                .HasMaxLength(200)
                .HasColumnName("GiamHo_HoTen");
            entity.Property(e => e.GiamHoMoiQuanHe)
                .HasMaxLength(50)
                .HasColumnName("GiamHo_MoiQuanHe");
            entity.Property(e => e.GiamHoSoCccd)
                .HasMaxLength(20)
                .HasColumnName("GiamHo_SoCCCD");
            entity.Property(e => e.HoTen).HasMaxLength(200);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdgioiTinh).HasColumnName("IDGioiTinh");
            entity.Property(e => e.IddanToc).HasColumnName("IDDanToc");
            entity.Property(e => e.IdphuongXa).HasColumnName("IDPhuongXa");
            entity.Property(e => e.IdtinhThanh).HasColumnName("IDTinhThanh");
            entity.Property(e => e.MaBn)
                .HasMaxLength(30)
                .HasColumnName("MaBN");
            entity.Property(e => e.NgayCapNhat).HasPrecision(0);
            entity.Property(e => e.NgayTao)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.NgheNghiep).HasMaxLength(150);
            entity.Property(e => e.QuocTich).HasMaxLength(100);
            entity.Property(e => e.SoCccd)
                .HasMaxLength(20)
                .HasColumnName("SoCCCD");
            entity.Property(e => e.SoNhaTenDuong).HasMaxLength(300);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlBenhNhan)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_BenhNhan_CSKCB");

            entity.HasOne(d => d.DmDanToc).WithMany(p => p.QlBenhNhan)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IddanToc })
                .HasConstraintName("FK_QL_BenhNhan_DanToc");

            entity.HasOne(d => d.DmGioiTinh).WithMany(p => p.QlBenhNhan)
                .HasForeignKey(d => d.IdgioiTinh)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_BenhNhan_GioiTinh");

            entity.HasOne(d => d.DmPhuongXa).WithMany(p => p.QlBenhNhan)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdphuongXa })
                .HasConstraintName("FK_QL_BenhNhan_PX");

            entity.HasOne(d => d.DmTinhThanh).WithMany(p => p.QlBenhNhan)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtinhThanh })
                .HasConstraintName("FK_QL_BenhNhan_Tinh");
        });

        modelBuilder.Entity<QlChanDoanCt>(entity =>
        {
            entity.ToTable("QL_ChanDoan_CT");

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "IX_QL_ChanDoanCT_VV");

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien, e.MaBenh }, "UQ_QL_ChanDoanCT_Benh").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_ChanDoanCT_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "UX_QL_ChanDoan_CT_BenhChinh")
                .IsUnique()
                .HasFilter("([BenhChinh]=(1))");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.IdbacSi).HasColumnName("IDBacSi");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.Idicd10).HasColumnName("IDICD10");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.MaBenh).HasMaxLength(20);
            entity.Property(e => e.NgayGioChanDoan)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.TenBenh).HasMaxLength(500);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlChanDoanCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ChanDoanCT_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlChanDoanCt)
                .HasForeignKey(d => d.IdbacSi)
                .HasConstraintName("FK_QL_ChanDoanCT_BS");

            entity.HasOne(d => d.DmIcd10).WithMany(p => p.QlChanDoanCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.Idicd10 })
                .HasConstraintName("FK_QL_ChanDoanCT_ICD");

            entity.HasOne(d => d.QlVaoVien).WithOne(p => p.QlChanDoanCt)
                .HasPrincipalKey<QlVaoVien>(p => new { p.Idcskcb, p.Id })
                .HasForeignKey<QlChanDoanCt>(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ChanDoanCT_VV");
        });

        modelBuilder.Entity<QlChiDinhCt>(entity =>
        {
            entity.ToTable("QL_ChiDinh_CT", t => t.HasTrigger("TR_QL_ChiDinh_CT_KyPdf"));

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "IX_QL_ChiDinhCT_VV");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_ChiDinhCT_CSKCB_ID").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.DuongDanKetQua).HasMaxLength(1000);
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.IdbacSiChiDinh).HasColumnName("IDBacSiChiDinh");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IddichVu).HasColumnName("IDDichVu");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.NgayGioChiDinh)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.NoiGuiNgoai).HasMaxLength(300);
            entity.Property(e => e.SoLuong)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(10, 2)");
            entity.Property(e => e.ThanhTien).HasColumnType("decimal(18, 2)");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlChiDinhCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ChiDinhCT_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlChiDinhCt)
                .HasForeignKey(d => d.IdbacSiChiDinh)
                .HasConstraintName("FK_QL_ChiDinhCT_BS");

            entity.HasOne(d => d.DmDichVu).WithMany(p => p.QlChiDinhCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IddichVu })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ChiDinhCT_DV");

            entity.HasOne(d => d.QlVaoVien).WithMany(p => p.QlChiDinhCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ChiDinhCT_VV");
        });

        modelBuilder.Entity<QlCongKham>(entity =>
        {
            entity.ToTable("QL_CongKham");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_CongKham_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "UQ_QL_CongKham_VV").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdnguoiTao).HasColumnName("IDNguoiTao");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.NgayTao)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlCongKham)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_CongKham_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlCongKham)
                .HasForeignKey(d => d.IdnguoiTao)
                .HasConstraintName("FK_QL_CongKham_NV");

            entity.HasOne(d => d.QlVaoVien).WithOne(p => p.QlCongKham)
                .HasPrincipalKey<QlVaoVien>(p => new { p.Idcskcb, p.Id })
                .HasForeignKey<QlCongKham>(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_CongKham_VV");
        });

        modelBuilder.Entity<QlCongKhamCt>(entity =>
        {
            entity.ToTable("QL_CongKham_CT");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_CongKhamCT_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.IdcongKham, e.IddichVu }, "UQ_QL_CongKhamCT_DV").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.IdcongKham).HasColumnName("IDCongKham");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IddichVu).HasColumnName("IDDichVu");
            entity.Property(e => e.SoLuong)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(10, 2)");
            entity.Property(e => e.ThanhTien).HasColumnType("decimal(18, 2)");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlCongKhamCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_CongKhamCT_CSKCB");

            entity.HasOne(d => d.QlCongKham).WithMany(p => p.QlCongKhamCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdcongKham })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_CongKhamCT_CongKham");

            entity.HasOne(d => d.DmDichVu).WithMany(p => p.QlCongKhamCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IddichVu })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_CongKhamCT_DV");
        });

        modelBuilder.Entity<QlPhieuSinhHieu>(entity =>
        {
            entity.ToTable("QL_PhieuSinhHieu", t => t.HasTrigger("TR_QL_PhieuSinhHieu_KyPdf"));

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien, e.NgayGioDo }, "IX_QL_PhieuSinhHieu_VV").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "UQ_QL_PhieuSinhHieu_CSKCB_VV").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_PhieuSinhHieu_CSKCB_ID").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdnhanVien).HasColumnName("IDNhanVien");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.NgayGioDo)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlPhieuSinhHieu)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_PhieuSinhHieu_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlPhieuSinhHieu)
                .HasForeignKey(d => d.IdnhanVien)
                .HasConstraintName("FK_QL_PhieuSinhHieu_NV");

            entity.HasOne(d => d.QlVaoVien).WithMany(p => p.QlPhieuSinhHieu)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_PhieuSinhHieu_VV");
        });

        modelBuilder.Entity<QlPhieuSinhHieuCt>(entity =>
        {
            entity.ToTable("QL_PhieuSinhHieu_CT", t => t.HasTrigger("TR_QL_PhieuSinhHieu_CT_KyPdf"));

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_PhieuSinhHieuCT_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.IdphieuSinhHieu, e.IdtriSoSinhHieu }, "UQ_QL_PhieuSinhHieuCT_TriSo").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.GiaTri).HasMaxLength(100);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdphieuSinhHieu).HasColumnName("IDPhieuSinhHieu");
            entity.Property(e => e.IdtriSoSinhHieu).HasColumnName("IDTriSoSinhHieu");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlPhieuSinhHieuCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_PhieuSinhHieuCT_CSKCB");

            entity.HasOne(d => d.QlPhieuSinhHieu).WithMany(p => p.QlPhieuSinhHieuCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdphieuSinhHieu })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_PhieuSinhHieuCT_Phieu");

            entity.HasOne(d => d.DmTriSoSinhHieu).WithMany(p => p.QlPhieuSinhHieuCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtriSoSinhHieu })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_PhieuSinhHieuCT_TriSo");
        });

        modelBuilder.Entity<QlThuTien>(entity =>
        {
            entity.ToTable("QL_ThuTien");

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_ThuTien_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien }, "UQ_QL_ThuTien_VV").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.SoPhieu }, "UX_QL_ThuTien_SoPhieu")
                .IsUnique()
                .HasFilter("([SoPhieu] IS NOT NULL)");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.ChuyenKhoan).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdnganHang).HasColumnName("IDNganHang");
            entity.Property(e => e.IdnhanVienThu).HasColumnName("IDNhanVienThu");
            entity.Property(e => e.IdtaiKhoanThu).HasColumnName("IDTaiKhoanThu");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.NgayGioThu).HasPrecision(0);
            entity.Property(e => e.SoPhieu).HasMaxLength(30);
            entity.Property(e => e.ThucThu).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TienGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TienMat).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TongTien).HasColumnType("decimal(18, 2)");

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlThuTien)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ThuTien_CSKCB");

            entity.HasOne(d => d.IdnganHangNavigation).WithMany(p => p.QlThuTien)
                .HasForeignKey(d => d.IdnganHang)
                .HasConstraintName("FK_QL_ThuTien_NH");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlThuTien)
                .HasForeignKey(d => d.IdnhanVienThu)
                .HasConstraintName("FK_QL_ThuTien_NV");

            entity.HasOne(d => d.QlVaoVien).WithOne(p => p.QlThuTien)
                .HasPrincipalKey<QlVaoVien>(p => new { p.Idcskcb, p.Id })
                .HasForeignKey<QlThuTien>(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ThuTien_VV");
        });

        modelBuilder.Entity<QlThuTienCt>(entity =>
        {
            entity.ToTable("QL_ThuTien_CT");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.IdchiDinhCt).HasColumnName("IDChiDinhCT");
            entity.Property(e => e.IdcongKhamCt).HasColumnName("IDCongKhamCT");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdthuTien).HasColumnName("IDThuTien");
            entity.Property(e => e.IdtoaThuocCt).HasColumnName("IDToaThuocCT");
            entity.Property(e => e.SoLuong)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(10, 2)");
            entity.Property(e => e.ThanhTien).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.PhuThu).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.GiamPhanTram).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.ThucThu).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TienGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.IdnhanVienHuy).HasColumnName("IDNhanVienHuy");
            entity.Property(e => e.IdtaiKhoanHuy).HasColumnName("IDTaiKhoanHuy");
            entity.Property(e => e.NgayGioHuy).HasPrecision(0);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlThuTienCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ThuTienCT_CSKCB");

            entity.HasOne(d => d.QlChiDinhCt).WithMany(p => p.QlThuTienCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdchiDinhCt })
                .HasConstraintName("FK_QL_ThuTienCT_CD");

            entity.HasOne(d => d.QlCongKhamCt).WithMany(p => p.QlThuTienCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdcongKhamCt })
                .HasConstraintName("FK_QL_ThuTienCT_CK");

            entity.HasOne(d => d.QlThuTien).WithMany(p => p.QlThuTienCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdthuTien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ThuTienCT_Thu");

            entity.HasOne(d => d.QlToaThuocCt).WithMany(p => p.QlThuTienCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtoaThuocCt })
                .HasConstraintName("FK_QL_ThuTienCT_Toa");
        });

        modelBuilder.Entity<QlToaThuocCt>(entity =>
        {
            entity.ToTable("QL_ToaThuoc_CT");

            entity.HasIndex(e => new { e.Idcskcb, e.IdvaoVien, e.NgayKe }, "IX_QL_ToaThuocCT_VV").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_ToaThuocCT_CSKCB_ID").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.CachDung).HasMaxLength(500);
            entity.Property(e => e.Chieu).HasMaxLength(50);
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.HoatChat).HasMaxLength(1000);
            entity.Property(e => e.IdbacSiKe).HasColumnName("IDBacSiKe");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.Idthuoc).HasColumnName("IDThuoc");
            entity.Property(e => e.IdtoaThuocCtgoc).HasColumnName("IDToaThuocCTGoc");
            entity.Property(e => e.IddonViTinhDung).HasColumnName("IDDonViTinhDung");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.IdtoaThuoc).HasColumnName("IDToaThuoc");
            entity.Property(e => e.MaLoaiToaThuoc).HasMaxLength(1).HasColumnName("MaLoaiToaThuoc").HasDefaultValue("c");
            entity.Property(e => e.LieuDung).HasMaxLength(300);
            entity.Property(e => e.NgayKe)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Sang).HasMaxLength(50);
            entity.Property(e => e.SoLuong).HasColumnType("decimal(10, 2)");
            entity.Property(e => e.ThanhTien).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Toi).HasMaxLength(50);
            entity.Property(e => e.Trua).HasMaxLength(50);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlToaThuocCt)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ToaThuocCT_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlToaThuocCt)
                .HasForeignKey(d => d.IdbacSiKe)
                .HasConstraintName("FK_QL_ToaThuocCT_BS");

            entity.HasOne(d => d.DmLoaiToaThuoc).WithMany(p => p.QlToaThuocCt)
                .HasForeignKey(d => d.MaLoaiToaThuoc)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ToaThuocCT_LoaiToaThuoc");

            entity.HasOne(d => d.DmThuoc).WithMany(p => p.QlToaThuocCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.Idthuoc })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ToaThuocCT_Thuoc");

            entity.HasOne<DmDonViTinh>()
                .WithMany()
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IddonViTinhDung })
                .HasConstraintName("FK_QL_ToaThuocCT_DonViTinhDung");

            entity.HasOne(d => d.QlToaThuocCtNavigation).WithMany(p => p.InverseQlToaThuocCtNavigation)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtoaThuocCtgoc })
                .HasConstraintName("FK_QL_ToaThuocCT_Goc");

            entity.HasOne(d => d.QlVaoVien).WithMany(p => p.QlToaThuocCt)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdvaoVien })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_ToaThuocCT_VV");

            entity.HasOne(d => d.QlToaThuoc).WithMany(p => p.ChiTiet)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdtoaThuoc })
                .HasConstraintName("FK_QL_ToaThuocCT_ToaThuoc");
        });

        modelBuilder.Entity<QlToaThuoc>(entity =>
        {
            entity.ToTable("QL_ToaThuoc");
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.Idcskcb, e.Id }).IsUnique().HasDatabaseName("UQ_QL_ToaThuoc_CSKCB_ID");
            entity.HasIndex(e => e.MaToaQuocGia).IsUnique().HasFilter("[MaToaQuocGia] IS NOT NULL").HasDatabaseName("UQ_QL_ToaThuoc_MaQuocGia");
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdvaoVien).HasColumnName("IDVaoVien");
            entity.Property(e => e.IdbacSiKe).HasColumnName("IDBacSiKe");
            entity.Property(e => e.IdphienBanHienTai).HasColumnName("IDPhienBanHienTai");
            entity.Property(e => e.NgayKe).HasColumnType("date");
            entity.Property(e => e.MaLoaiToaThuoc).HasMaxLength(1);
            entity.Property(e => e.MaToaQuocGia).HasMaxLength(14);
            entity.Property(e => e.TrangThai).HasMaxLength(30);
            entity.Property(e => e.NgayTao).HasPrecision(0);
            entity.Property(e => e.NgayCapNhat).HasPrecision(0);
        });

        modelBuilder.Entity<QlToaThuocPhienBan>(entity =>
        {
            entity.ToTable("QL_ToaThuoc_PhienBan");
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.Idcskcb, e.IdtoaThuoc, e.SoPhienBan }).IsUnique();
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdtoaThuoc).HasColumnName("IDToaThuoc");
            entity.Property(e => e.IdbacSiKy).HasColumnName("IDBacSiKy");
            entity.Property(e => e.IdtaiKhoanKy).HasColumnName("IDTaiKhoanKy");
            entity.Property(e => e.TrangThai).HasMaxLength(30);
            entity.Property(e => e.Sha256Json).HasMaxLength(64);
            entity.Property(e => e.Sha256Pdf).HasMaxLength(64);
            entity.Property(e => e.NhaCungCapKy).HasMaxLength(100);
            entity.Property(e => e.SerialChungThu).HasMaxLength(200);
            entity.Property(e => e.NgayGioKy).HasPrecision(0);
            entity.Property(e => e.NgayTao).HasPrecision(0);
            entity.HasOne(e => e.ToaThuoc).WithMany(e => e.PhienBan)
                .HasPrincipalKey(e => new { e.Idcskcb, e.Id })
                .HasForeignKey(e => new { e.Idcskcb, e.IdtoaThuoc })
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<QlToaThuocLanGui>(entity =>
        {
            entity.ToTable("QL_ToaThuoc_LanGui");
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.IdempotencyKey).IsUnique();
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdtoaThuocPhienBan).HasColumnName("IDToaThuocPhienBan");
            entity.Property(e => e.IdbacSiYeuCau).HasColumnName("IDBacSiYeuCau");
            entity.Property(e => e.IdtaiKhoanYeuCau).HasColumnName("IDTaiKhoanYeuCau");
            entity.Property(e => e.TrangThai).HasMaxLength(30);
            entity.Property(e => e.MaKetQua).HasMaxLength(100);
            entity.Property(e => e.NgayTao).HasPrecision(0);
            entity.Property(e => e.BatDauLuc).HasPrecision(0);
            entity.Property(e => e.KetThucLuc).HasPrecision(0);
            entity.HasOne(e => e.PhienBan).WithMany(e => e.LanGui)
                .HasForeignKey(e => e.IdtoaThuocPhienBan)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<QlToaThuocAudit>(entity =>
        {
            entity.ToTable("QL_ToaThuoc_Audit");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdtoaThuoc).HasColumnName("IDToaThuoc");
            entity.Property(e => e.IdtoaThuocPhienBan).HasColumnName("IDToaThuocPhienBan");
            entity.Property(e => e.IdnhanVien).HasColumnName("IDNhanVien");
            entity.Property(e => e.IdtaiKhoan).HasColumnName("IDTaiKhoan");
            entity.Property(e => e.HanhDong).HasMaxLength(50);
            entity.Property(e => e.TrangThaiTu).HasMaxLength(30);
            entity.Property(e => e.TrangThaiDen).HasMaxLength(30);
            entity.Property(e => e.NgayTao).HasPrecision(0);
        });

        modelBuilder.Entity<HtLienThongToaThuocCauHinh>(entity =>
        {
            entity.ToTable("HT_LienThongToaThuoc_CauHinh");
            entity.HasKey(e => e.Idcskcb);
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB").ValueGeneratedNever();
            entity.Property(e => e.MoiTruong).HasMaxLength(10);
            entity.Property(e => e.ApiBaseUrlProduction).HasMaxLength(500);
            entity.Property(e => e.ApiBaseUrlTest).HasMaxLength(500);
            entity.Property(e => e.UrlKyDuLieu).HasMaxLength(500);
            entity.Property(e => e.UrlKyPdf).HasMaxLength(500);
            entity.Property(e => e.MaLienThongCskcb).HasMaxLength(100);
            entity.Property(e => e.MatKhauCskcbMaHoa).HasColumnType("nvarchar(max)");
            entity.Property(e => e.IdtaiKhoanCapNhat).HasColumnName("IDTaiKhoanCapNhat");
            entity.Property(e => e.NgayCapNhat).HasPrecision(0);
        });

        modelBuilder.Entity<HtLienThongToaThuocBacSi>(entity =>
        {
            entity.ToTable("HT_LienThongToaThuoc_BacSi");
            entity.HasKey(e => new { e.Idcskcb, e.IdnhanVien });
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdnhanVien).HasColumnName("IDNhanVien");
            entity.Property(e => e.MaLienThong).HasMaxLength(100);
            entity.Property(e => e.SoChungChiHanhNghe).HasMaxLength(100);
            entity.Property(e => e.MatKhauMaHoa).HasColumnType("nvarchar(max)");
            entity.Property(e => e.IdtaiKhoanCapNhat).HasColumnName("IDTaiKhoanCapNhat");
            entity.Property(e => e.NgayCapNhat).HasPrecision(0);
        });

        modelBuilder.Entity<QlVaoVien>(entity =>
        {
            entity.ToTable("QL_VaoVien", t => t.HasTrigger("TR_QL_VaoVien_KyPdf"));

            entity.HasIndex(e => new { e.Idcskcb, e.Ngay, e.DaChuyenKham, e.TrangThaiKham, e.NgayGioVaoVien }, "IX_QL_VaoVien_DS").IsDescending(false, false, false, false, true);

            entity.HasIndex(e => new { e.Idcskcb, e.IdbenhNhan, e.NgayGioVaoVien }, "IX_QL_VaoVien_LichSu").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.Idcskcb, e.Id }, "UQ_QL_VaoVien_CSKCB_ID").IsUnique();

            entity.HasIndex(e => new { e.Idcskcb, e.MaVaoVien }, "UQ_QL_VaoVien_CSKCB_Ma").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.BatDauKhamLuc).HasPrecision(0);
            entity.Property(e => e.GhiChuTiepNhan).HasMaxLength(1000);
            entity.Property(e => e.DanDo).HasMaxLength(1000);
            entity.Property(e => e.IdbacSiKham).HasColumnName("IDBacSiKham");
            entity.Property(e => e.IdbenhNhan).HasColumnName("IDBenhNhan");
            entity.Property(e => e.Idcskcb).HasColumnName("IDCSKCB");
            entity.Property(e => e.IdnguoiTiepNhan).HasColumnName("IDNguoiTiepNhan");
            entity.Property(e => e.IdphacDo).HasColumnName("IDPhacDo");
            entity.Property(e => e.KetThucKhamLuc).HasPrecision(0);
            entity.Property(e => e.MaPdgoc)
                .HasMaxLength(50)
                .HasColumnName("MaPDGoc");
            entity.Property(e => e.MaVaoVien).HasMaxLength(30);
            entity.Property(e => e.Ngay).HasDefaultValueSql("(CONVERT([date],sysdatetime()))");
            entity.Property(e => e.NgayCapNhat).HasPrecision(0);
            entity.Property(e => e.NgayLuuKhamLanDau).HasPrecision(0);
            entity.Property(e => e.NgayCapNhatKham).HasPrecision(0);
            entity.Property(e => e.PhienBanLamSang).HasDefaultValue(0L);
            entity.Property(e => e.NgayGioVaoVien)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.NgayTao)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.ThoiGianChuyenKham).HasPrecision(0);
            entity.Property(e => e.TrieuChung).HasMaxLength(2000);

            entity.HasOne(d => d.IdcskcbNavigation).WithMany(p => p.QlVaoVien)
                .HasForeignKey(d => d.Idcskcb)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_VaoVien_CSKCB");

            entity.HasOne(d => d.DmNhanVien).WithMany(p => p.QlVaoVienDmNhanVien)
                .HasForeignKey(d => d.IdbacSiKham)
                .HasConstraintName("FK_QL_VaoVien_BS");

            entity.HasOne(d => d.QlBenhNhan).WithMany(p => p.QlVaoVien)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdbenhNhan })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QL_VaoVien_BN");

            entity.HasOne(d => d.DmNhanVienNavigation).WithMany(p => p.QlVaoVienDmNhanVienNavigation)
                .HasForeignKey(d => d.IdnguoiTiepNhan)
                .HasConstraintName("FK_QL_VaoVien_TiepNhan");

            entity.HasOne(d => d.DmPhacDo).WithMany(p => p.QlVaoVien)
                .HasPrincipalKey(p => new { p.Idcskcb, p.Id })
                .HasForeignKey(d => new { d.Idcskcb, d.IdphacDo })
                .HasConstraintName("FK_QL_VaoVien_PhacDo");
        });
        modelBuilder.HasSequence("SEQ_MaBenhNhan");
        modelBuilder.HasSequence("SEQ_MaBN");
        modelBuilder.HasSequence("SEQ_MaVaoVien");
        modelBuilder.HasSequence("SEQ_SoPhieuThu");

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
