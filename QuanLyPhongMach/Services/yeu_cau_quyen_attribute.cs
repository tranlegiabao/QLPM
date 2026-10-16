using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace QuanLyPhongMach.Services;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true, Inherited = true)]
public sealed class yeu_cau_quyen_attribute : Attribute, IAsyncAuthorizationFilter
{
    private readonly string _ma_chuc_nang;
    private readonly string _loai_quyen;

    public yeu_cau_quyen_attribute(string ma_chuc_nang, string loai_quyen = "Xem")
    {
        _ma_chuc_nang = ma_chuc_nang;
        _loai_quyen = loai_quyen;
    }

    public Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;
        if (user?.Identity?.IsAuthenticated != true)
        {
            context.Result = new ChallengeResult();
            return Task.CompletedTask;
        }

        if (!user.CoQuyen(_ma_chuc_nang, _loai_quyen))
        {
            var path = context.HttpContext.Request.Path;
            context.Result = path.StartsWithSegments("/api")
                ? new ForbidResult()
                : new NotFoundResult();
        }

        return Task.CompletedTask;
    }
}
