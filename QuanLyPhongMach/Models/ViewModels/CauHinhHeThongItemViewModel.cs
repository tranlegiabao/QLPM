namespace QuanLyPhongMach.Models.ViewModels;

public sealed class CauHinhHeThongItemViewModel
{
    public string MaChucNang { get; init; } = string.Empty;

    public bool HieuLuc { get; init; }

    public string Nhom { get; init; } = string.Empty;

    public string GhiChu { get; init; } = string.Empty;
}

public sealed class CauHinhHeThongViewModel
{
    public long IdCskcb { get; init; }

    public string TenCskcb { get; init; } = string.Empty;

    public IReadOnlyList<CauHinhHeThongItemViewModel> DanhSach { get; init; }
        = Array.Empty<CauHinhHeThongItemViewModel>();
}
