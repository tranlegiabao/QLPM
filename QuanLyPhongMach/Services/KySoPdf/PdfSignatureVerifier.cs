using System.Globalization;
using System.Security.Cryptography;
using System.Security.Cryptography.Pkcs;
using System.Text;
using System.Text.RegularExpressions;
using QuanLyPhongMach.Services.ToaThuocQuocGia;

namespace QuanLyPhongMach.Services.KySoPdf;

public static class PdfSignatureVerifier
{
    // Validate the detached CMS against the actual ByteRange, including the final
    // bytes of the PDF. This verifies integrity, not CA trust/revocation/PAdES-LTV.
    public static string Verify(byte[] pdf)
    {
        if (pdf.Length < 8 || pdf.Length > 10 * 1024 * 1024 || Encoding.ASCII.GetString(pdf,0,5)!="%PDF-")
            throw Invalid();
        var text=Encoding.Latin1.GetString(pdf);
        foreach (Match match in Regex.Matches(text,@"/ByteRange\s*\[\s*0\s+(\d+)\s+(\d+)\s+(\d+)\s*\]",RegexOptions.CultureInvariant,TimeSpan.FromSeconds(1)))
        {
            if (!int.TryParse(match.Groups[1].Value,NumberStyles.None,CultureInfo.InvariantCulture,out var first)
                || !int.TryParse(match.Groups[2].Value,NumberStyles.None,CultureInfo.InvariantCulture,out var second)
                || !int.TryParse(match.Groups[3].Value,NumberStyles.None,CultureInfo.InvariantCulture,out var length)
                || first<=0 || second<=first || second>pdf.Length || length!=pdf.Length-second) continue;
            var gap=text.Substring(first,second-first).Trim();
            if (gap.Length<4 || gap[0]!='<' || gap[^1]!='>') continue;
            try
            {
                var hex=Regex.Replace(gap[1..^1],@"\s",string.Empty);
                var der=Convert.FromHexString(hex);
                // Contents is padded with zero bytes. Read its DER length rather
                // than trimming zeros that may be part of the signature itself.
                if(der.Length<2 || der[0]!=0x30)continue;
                var header=2; var body=(int)der[1];
                if(body>=128)
                {
                    var count=body&127;if(count is <1 or >4 || der.Length<2+count)continue;
                    body=0;header+=count;
                    for(var i=0;i<count;i++)body=checked((body<<8)+der[2+i]);
                }
                if(body<=0 || body>der.Length-header)continue;
                var content=new byte[first+length];
                Buffer.BlockCopy(pdf,0,content,0,first);Buffer.BlockCopy(pdf,second,content,first,length);
                var cms=new SignedCms(new ContentInfo(content),true);
                cms.Decode(der.AsSpan(0,header+body).ToArray());
                if(!cms.Detached || cms.SignerInfos.Count!=1 || cms.SignerInfos[0].Certificate==null)continue;
                cms.CheckSignature(verifySignatureOnly:true);
                return cms.SignerInfos[0].Certificate!.SerialNumber;
            }
            catch(Exception ex) when(ex is CryptographicException or FormatException or OverflowException or ArgumentException)
            { /* A different embedded signature may cover the final revision. */ }
        }
        throw Invalid();
    }
    private static ToaThuocInteroperabilityException Invalid()=>new(502,"PDF trả về không có chữ ký CMS hợp lệ bao phủ toàn bộ tài liệu; không lưu đã ký.");
}
