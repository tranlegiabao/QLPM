using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using QuanLyPhongMach.Models.ViewModels;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    public HomeController(ILogger<HomeController> logger) => _logger = logger;

    public IActionResult Index()
    {
        if (User.Identity?.IsAuthenticated != true)
            return Redirect("/xac_thuc/dang_nhap");

        if (User.IsInRole("quan_tri_he_thong"))
            return Redirect("/he_thong");

        // Phân hệ Khám bệnh luôn ưu tiên mở từ tab Tiếp nhận.
        if (User.CoQuyen("tiep_nhan", "Xem"))
            return Redirect("/tiep_nhan");

        if (User.CoQuyen("kham_benh", "Xem"))
            return Redirect("/kham_benh");

        if (User.CoQuyen("thu_ngan", "Xem"))
            return Redirect("/thu_ngan");

        if (User.CoQuyen("kho_cap_phat", "Xem"))
            return Redirect("/kho");

        if (User.CoQuyen("kho", "Xem"))
            return Redirect("/kho/quan-ly");

        if (User.CoQuyen("he_thong_nhan_vien", "Xem")
            || User.CoQuyen("he_thong_tai_khoan", "Xem")
            || User.CoQuyen("he_thong_vai_tro", "Xem")
            || User.CoQuyen("he_thong_phan_quyen", "Xem"))
            return Redirect("/he_thong");

        return Redirect("/xac_thuc/cam_truy_cap");
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
        => View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
}
