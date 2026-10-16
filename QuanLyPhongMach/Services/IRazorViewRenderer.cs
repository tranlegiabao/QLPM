namespace QuanLyPhongMach.Services;

public interface IRazorViewRenderer
{
    Task<string> RenderAsync<TModel>(string viewName, TModel model);
}
