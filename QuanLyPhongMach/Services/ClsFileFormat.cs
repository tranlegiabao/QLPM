namespace QuanLyPhongMach.Services;

public sealed record ClsFileType(string Extension,string ContentType,bool IsImage);
public static class ClsFileFormat
{
    public static ClsFileType? FromPath(string path)=>Path.GetExtension(path).ToLowerInvariant() switch {
        ".pdf"=>new("pdf","application/pdf",false),
        ".jpg" or ".jpeg"=>new("jpg","image/jpeg",true),
        ".png"=>new("png","image/png",true),
        ".webp"=>new("webp","image/webp",true),
        _=>null
    };
    public static bool Matches(ClsFileType type,ReadOnlySpan<byte> header)=>type.Extension switch {
        "pdf"=>header.StartsWith("%PDF-"u8),
        "jpg"=>header.Length>=3 && header[0]==0xff && header[1]==0xd8 && header[2]==0xff,
        "png"=>header.StartsWith(new byte[]{137,80,78,71,13,10,26,10}),
        "webp"=>header.Length>=12 && header[..4].SequenceEqual("RIFF"u8) && header.Slice(8,4).SequenceEqual("WEBP"u8),
        _=>false
    };
}

