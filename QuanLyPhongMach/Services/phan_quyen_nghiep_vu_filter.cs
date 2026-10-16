using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;

namespace QuanLyPhongMach.Services
{
    /// <summary>
    /// Bảo vệ các phân hệ nghiệp vụ cũ ở server-side.
    /// Các controller có attribute quyền riêng được kiểm tra trực tiếp tại action.
    /// </summary>
    public sealed class phan_quyen_nghiep_vu_filter : IAsyncAuthorizationFilter
    {
        public Task OnAuthorizationAsync(AuthorizationFilterContext context)
        {
            var user = context.HttpContext.User;
            if (user?.Identity?.IsAuthenticated != true)
            {
                return Task.CompletedTask;
            }

            var descriptor = context.ActionDescriptor as ControllerActionDescriptor;
            var controller = descriptor?.ControllerName?.ToLowerInvariant() ?? string.Empty;
            var path = context.HttpContext.Request.Path.Value?.ToLowerInvariant() ?? string.Empty;
            var method = context.HttpContext.Request.Method.ToUpperInvariant();

            string? maChucNang = null;
            string loaiQuyen = "Xem";

            switch (controller)
            {
                case "tiep_nhan":
                    maChucNang = "tiep_nhan";
                    loaiQuyen = method == "GET" ? "Xem" : (path.Contains("xoa") || path.Contains("bo_dang_ky") ? "Xoa" : "Sua");
                    break;

                case "kham_benh":
                    maChucNang = "kham_benh";
                    loaiQuyen = method == "GET" ? "Xem" : "Sua";
                    break;

                case "phac_do":
                    maChucNang = "phac_do";
                    loaiQuyen = method == "GET" ? "Xem" : (path.Contains("xoa") ? "Xoa" : "Sua");
                    break;

                case "thu_ngan":
                    maChucNang = "thu_ngan";
                    loaiQuyen = method == "GET"
                        ? (path.Contains("in-phieu") || path.Contains("bao-cao") ? "Xuat" : "Xem")
                        : path.Contains("thu-tien") ? "Them"
                        : path.Contains("huy-") ? "Xoa"
                        : "Sua";
                    break;

                case "kho":
                    // Hai màn có quyền riêng; chỉ danh sách kho mặc định dùng chung.
                    if (descriptor?.ActionName == "DanhSachKho")
                    {
                        if (!user.CoQuyen("kho", "Xem") && !user.CoQuyen("kho_cap_phat", "Xem"))
                            context.Result = new ForbidResult();
                        return Task.CompletedTask;
                    }
                    maChucNang = descriptor?.ActionName is "Index" or "ChoCap" or "ChiTietCap"
                        or "XuatThuoc" or "DongDaCap" or "HoanThuoc" ? "kho_cap_phat" : "kho";
                    // URL cũ của các tab quản lý vẫn được chuyển về màn quản lý.
                    if (descriptor?.ActionName == "Index" &&
                        context.HttpContext.Request.Query["tab"].ToString() is "ton-kho" or "nhap-kho" or "dieu-chinh" or "phan-nhom")
                        maChucNang = "kho";
                    loaiQuyen = method == "GET"
                        ? (path.Contains("bao-cao") || path.Contains("in-") ? "Xuat" : "Xem")
                        : path.Contains("nhap-kho") || path.Contains("nha-cung-cap/them") ? "Them"
                        : path.Contains("hoan-thuoc") || path.Contains("phieu-nhap/huy") || path.Contains("dieu-chinh-ton") ? "Xoa"
                        : "Sua";
                    break;

                case "kho_chung_tu":
                    maChucNang = descriptor?.ActionName is "PhieuNhapPdf" or "PhieuNhapExcel" ? "kho" : "kho_cap_phat";
                    loaiQuyen = "Xem";
                    break;

                case "danh_muc":
                    if (method != "GET")
                    {
                        maChucNang = "danh_muc";
                        loaiQuyen = "Sua";
                    }
                    break;

                case "cls_ket_qua":
                    maChucNang = "kham_benh";
                    loaiQuyen = method == "GET" ? "Xem" : "Sua";
                    break;
            }

            if (!string.IsNullOrWhiteSpace(maChucNang) && !user.CoQuyen(maChucNang, loaiQuyen))
            {
                context.Result = path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase)
                    ? new ForbidResult()
                    : new NotFoundResult();
            }

            return Task.CompletedTask;
        }
    }
}
