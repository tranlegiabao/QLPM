using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Dynamic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace QuanLyPhongMach.Data
{
    public partial class QlpmDbContext
    {
        private static void GanThamSo(DbCommand cmd, object? tham_so)
        {
            if (tham_so == null) return;

            if (tham_so is IEnumerable<DbParameter> dbParams)
            {
                foreach (var p in dbParams)
                {
                    cmd.Parameters.Add(p);
                }
                return;
            }

            foreach (var prop in tham_so.GetType().GetProperties())
            {
                var val = prop.GetValue(tham_so);
                var p = cmd.CreateParameter();
                p.ParameterName = "@" + prop.Name;
                if (val == null)
                {
                    p.Value = DBNull.Value;
                }
                else if (val is DateOnly d)
                {
                    p.Value = d.ToDateTime(TimeOnly.MinValue);
                }
                else
                {
                    p.Value = val;
                }
                cmd.Parameters.Add(p);
            }
        }

        public async Task<dynamic?> LayMotDongStoAsync(string ten_sto, object? tham_so = null)
        {
            var conn = Database.GetDbConnection();
            if (conn.State != ConnectionState.Open)
            {
                await conn.OpenAsync();
            }

            using var cmd = conn.CreateCommand();
            cmd.CommandText = ten_sto;
            cmd.CommandType = CommandType.StoredProcedure;
            GanThamSo(cmd, tham_so);

            using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                IDictionary<string, object?> expando = new ExpandoObject();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    expando[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                }
                return expando;
            }

            return null;
        }

        public async Task<List<dynamic>> LayDanhSachStoAsync(string ten_sto, object? tham_so = null)
        {
            var conn = Database.GetDbConnection();
            if (conn.State != ConnectionState.Open)
            {
                await conn.OpenAsync();
            }

            using var cmd = conn.CreateCommand();
            cmd.CommandText = ten_sto;
            cmd.CommandType = CommandType.StoredProcedure;
            GanThamSo(cmd, tham_so);

            var result = new List<dynamic>();
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                IDictionary<string, object?> expando = new ExpandoObject();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    expando[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                }
                result.Add(expando);
            }

            return result;
        }

        public async Task<int> ThucThiStoAsync(string ten_sto, object? tham_so = null)
        {
            var conn = Database.GetDbConnection();
            if (conn.State != ConnectionState.Open)
            {
                await conn.OpenAsync();
            }

            using var cmd = conn.CreateCommand();
            cmd.CommandText = ten_sto;
            cmd.CommandType = CommandType.StoredProcedure;
            GanThamSo(cmd, tham_so);

            return await cmd.ExecuteNonQueryAsync();
        }

        public async Task<DbMultipleResult> QueryMultipleStoAsync(string ten_sto, object? tham_so = null)
        {
            var conn = Database.GetDbConnection();
            if (conn.State != ConnectionState.Open)
            {
                await conn.OpenAsync();
            }

            var cmd = conn.CreateCommand();
            cmd.CommandText = ten_sto;
            cmd.CommandType = CommandType.StoredProcedure;
            GanThamSo(cmd, tham_so);

            var reader = await cmd.ExecuteReaderAsync();
            return new DbMultipleResult(cmd, reader);
        }

    }
}
