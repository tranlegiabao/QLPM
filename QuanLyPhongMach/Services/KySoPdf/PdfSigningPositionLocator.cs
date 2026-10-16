using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.KySoPdf;

public sealed record PdfSigningPosition(int Page,decimal X,decimal Y,decimal Width,decimal Height);

public static class PdfSigningPositionLocator
{
    // Markers are white 1px text inside the reserved doctor-signature space.
    // Read the final rendered PDF, including pagination and wkhtml scaling.
    public static IReadOnlyList<PdfSigningPosition> Locate(byte[] pdf,string type,decimal width,decimal height)
    {
        if(type is not ("toa_thuoc" or "chi_dinh") || width<=0 || height<=0)
            throw Invalid();
        var prefix=type=="toa_thuoc"?"QLPM_TOA":"QLPM_CD";
        PdfDocument document;
        try { document=PdfDocument.Open(pdf); }
        catch { throw Invalid(); }
        using var disposableDocument=document;
        var result=new List<PdfSigningPosition>();
        foreach(var page in document.GetPages())
        {
            var starts=Find(page.Letters,prefix+"_TOP");
            var ends=Find(page.Letters,prefix+"_BOTTOM");
            if(starts.Count!=ends.Count)throw Invalid();
            for(var i=0;i<starts.Count;i++)
            {
                var centerX=(decimal)starts[i].StartBaseLine.X;
                var top=(decimal)starts[i].StartBaseLine.Y;
                var bottom=(decimal)ends[i].StartBaseLine.Y;
                var x=centerX-width/2;var y=(top+bottom-height)/2;
                if(top<=bottom || top-bottom<height || x<0 || y<0 || x+width>(decimal)page.Width || y+height>(decimal)page.Height)
                    throw Invalid();
                result.Add(new(page.Number,decimal.Round(x,2),decimal.Round(y,2),width,height));
            }
        }
        if(result.Count==0 || result.Count>100)throw Invalid();
        return result;
    }
    private static List<Letter> Find(IReadOnlyList<Letter> letters,string marker)
    {
        var result=new List<Letter>();
        for(var i=0;i<letters.Count;i++)
        {
            if(letters[i].Value!=marker[..1])continue;
            var text=string.Empty;var j=i;
            while(j<letters.Count && text.Length<marker.Length)text+=letters[j++].Value;
            if(text==marker){result.Add(letters[i]);i=j-1;}
        }
        return result;
    }
    private static ToaThuocInteroperabilityException Invalid()=>new(422,"Không xác định được ô ký hoặc ô ký không đủ chỗ trong PDF. Kiểm tra mẫu in trước khi ký.");
}
