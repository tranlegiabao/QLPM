using System.Text.Json;
using System.Text.Json.Nodes;

namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public static class LienThongResponseSanitizer
{
    public static string Sanitize(string? body)
    {
        if (string.IsNullOrWhiteSpace(body)) return string.Empty;
        try {
            var node = JsonNode.Parse(body);
            Scrub(node);
            var value = node?.ToJsonString() ?? string.Empty;
            return value.Length > 4000 ? value[..4000] : value;
        } catch (JsonException) {
            return "Phản hồi không phải JSON; nội dung đã được ẩn.";
        }
    }
    private static void Scrub(JsonNode? node)
    {
        if (node is JsonObject obj) {
            foreach (var key in obj.Select(x => x.Key).ToArray()) {
                if (new[] { "token", "password", "secret", "authorization", "signature", "matkhau", "mat_khau" }
                    .Any(x => key.Contains(x, StringComparison.OrdinalIgnoreCase))) obj[key] = "***";
                else Scrub(obj[key]);
            }
        } else if (node is JsonArray array) {
            foreach (var item in array) Scrub(item);
        }
    }
}
