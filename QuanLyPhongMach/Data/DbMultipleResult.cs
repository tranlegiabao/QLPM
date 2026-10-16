using System.Data.Common;
using System.Dynamic;

namespace QuanLyPhongMach.Data;

public class DbMultipleResult : IAsyncDisposable
{
    private readonly DbCommand _cmd;
    private readonly DbDataReader _reader;

    public DbMultipleResult(DbCommand cmd, DbDataReader reader)
    {
        _cmd = cmd;
        _reader = reader;
    }

    public async Task<dynamic?> ReadFirstOrDefaultAsync()
    {
        dynamic? result = null;
        if (await _reader.ReadAsync())
        {
            IDictionary<string, object?> expando = new ExpandoObject();
            for (int i = 0; i < _reader.FieldCount; i++)
            {
                expando[_reader.GetName(i)] = _reader.IsDBNull(i) ? null : _reader.GetValue(i);
            }
            result = expando;
        }
        await _reader.NextResultAsync();
        return result;
    }

    public async Task<List<dynamic>> ReadAsync()
    {
        var list = new List<dynamic>();
        while (await _reader.ReadAsync())
        {
            IDictionary<string, object?> expando = new ExpandoObject();
            for (int i = 0; i < _reader.FieldCount; i++)
            {
                expando[_reader.GetName(i)] = _reader.IsDBNull(i) ? null : _reader.GetValue(i);
            }
            list.Add(expando);
        }
        await _reader.NextResultAsync();
        return list;
    }

    public async ValueTask DisposeAsync()
    {
        await _reader.DisposeAsync();
        await _cmd.DisposeAsync();
    }
}
