using Microsoft.AspNetCore.Mvc;
using QuanLyPhongMach.Services;

namespace QuanLyPhongMach.Controllers;

[yeu_cau_quyen_attribute("kho", "Xem")]
[Route("danh_muc")]
public sealed class danh_muc_nha_cung_cap_controller : Controller
{
    [HttpGet("nha_cung_cap")]
    public IActionResult Index()
    {
        if (User.LayIdCskcb() <= 0)
            return Redirect("/he_thong");

        ViewBag.ActiveTab = "danh_muc";
        ViewBag.HienThiThanhPhanHe = false;
        ViewBag.CoQuyenThem = User.CoQuyen("kho", "Them");
        ViewBag.CoQuyenSua = User.CoQuyen("kho", "Sua");
        ViewBag.CoQuyenXoa = User.CoQuyen("kho", "Xoa");
        return View("~/Views/danh_muc/NhaCungCap.cshtml");
    }
}
