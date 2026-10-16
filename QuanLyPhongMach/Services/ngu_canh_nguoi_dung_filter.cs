using System;
using System.Reflection;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;

namespace QuanLyPhongMach.Services
{
    /// <summary>
    /// Ép IDCSKCB và nhân viên nghiệp vụ từ phiên đăng nhập thay vì tin dữ liệu client gửi lên.
    /// Mục tiêu là tránh hard-code id_cskcb/id_bac_si/id_nguoi_tiep_nhan ở JavaScript
    /// và ngăn truy cập chéo cơ sở bằng cách sửa query/body phía client.
    /// </summary>
    public sealed class ngu_canh_nguoi_dung_filter : IAsyncActionFilter
    {
        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var user = context.HttpContext.User;
            if (user?.Identity?.IsAuthenticated != true)
            {
                await next();
                return;
            }

            var idCskcb = user.LayIdCskcb();
            var idNhanVien = user.LayIdNhanVien();
            if (idCskcb <= 0)
            {
                await next();
                return;
            }

            var descriptor = context.ActionDescriptor as ControllerActionDescriptor;
            var controllerName = descriptor?.ControllerName?.ToLowerInvariant() ?? string.Empty;

            foreach (var key in context.ActionArguments.Keys)
            {
                if (string.Equals(key, "id_cskcb", StringComparison.OrdinalIgnoreCase))
                {
                    context.ActionArguments[key] = idCskcb;
                }
                else if (idNhanVien > 0 && controllerName == "kham_benh" && string.Equals(key, "id_bac_si", StringComparison.OrdinalIgnoreCase))
                {
                    context.ActionArguments[key] = idNhanVien;
                }
                else if (idNhanVien > 0 && controllerName == "tiep_nhan" && string.Equals(key, "id_nguoi_tiep_nhan", StringComparison.OrdinalIgnoreCase))
                {
                    context.ActionArguments[key] = idNhanVien;
                }
                else if (idNhanVien > 0 && controllerName == "cls_ket_qua" && string.Equals(key, "id_nhan_vien", StringComparison.OrdinalIgnoreCase))
                {
                    context.ActionArguments[key] = idNhanVien;
                }
            }

            foreach (var argument in context.ActionArguments.Values)
            {
                if (argument == null) continue;

                GanLongNeuCo(argument, idCskcb, "IdCskcb", "id_cskcb");

                if (idNhanVien > 0 && controllerName == "kham_benh")
                {
                    GanLongNeuCo(argument, idNhanVien, "IdBacSi", "id_bac_si");
                }
                else if (idNhanVien > 0 && controllerName == "tiep_nhan")
                {
                    GanLongNeuCo(argument, idNhanVien, "IdNguoiTiepNhan", "id_nguoi_tiep_nhan");
                }
                else if (idNhanVien > 0 && controllerName == "cls_ket_qua")
                {
                    GanLongNeuCo(argument, idNhanVien, "IdNhanVien", "id_nhan_vien");
                }
            }

            await next();
        }

        private static void GanLongNeuCo(object target, long value, params string[] propertyNames)
        {
            foreach (var propertyName in propertyNames)
            {
                var prop = target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.IgnoreCase);
                if (prop == null || !prop.CanWrite) continue;

                if (prop.PropertyType == typeof(long))
                {
                    prop.SetValue(target, value);
                    return;
                }

                if (prop.PropertyType == typeof(long?))
                {
                    prop.SetValue(target, (long?)value);
                    return;
                }
            }
        }
    }
}
