using System;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using QuanLyPhongMach.Data;

namespace QuanLyPhongMach.Services
{
    /// <summary>
    /// Worker đồng bộ JSON danh mục theo version dirty của từng CSKCB.
    /// Lịch dùng giờ local của server/app; mặc định kiểm tra mỗi 30 giây.
    /// SQL application lock bảo đảm nhiều instance chỉ có một worker chạy một lượt.
    /// </summary>
    public sealed class danh_muc_json_worker : BackgroundService
    {
        private static readonly TimeSpan TickInterval = TimeSpan.FromSeconds(30);
        private static readonly TimeSpan RetryInterval = TimeSpan.FromMinutes(15);

        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<danh_muc_json_worker> _logger;

        public danh_muc_json_worker(
            IServiceScopeFactory scopeFactory,
            ILogger<danh_muc_json_worker> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("JSON danh mục worker đã khởi động.");

            try
            {
                await KiemTraVaChayNeuDenLichAsync(stoppingToken);

                using var timer = new PeriodicTimer(TickInterval);
                while (await timer.WaitForNextTickAsync(stoppingToken))
                {
                    await KiemTraVaChayNeuDenLichAsync(stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                _logger.LogInformation("JSON danh mục worker đang dừng.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "JSON danh mục worker dừng do lỗi ngoài dự kiến.");
            }
        }

        private async Task KiemTraVaChayNeuDenLichAsync(CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<QlpmDbContext>();
            var service = scope.ServiceProvider.GetRequiredService<danh_muc_json_dich_vu>();

            var connection = db.Database.GetDbConnection();
            if (connection.State != ConnectionState.Open)
                await connection.OpenAsync(cancellationToken);

            bool daKhoa = false;
            try
            {
                daKhoa = await ThuLockDemAsync(connection, cancellationToken);
                if (!daKhoa) return;

                var lich = await LayLichAsync(connection, cancellationToken);
                var now = await LayThoiGianServerSqlAsync(connection, cancellationToken);
                if (!CanChay(lich, now))
                    return;

                await BatDauLichAsync(connection, now, cancellationToken);

                var loi = new System.Collections.Generic.List<string>();

                var ids = await service.LayDanhSachCskcbCanDongBoJsonAsync();
                _logger.LogInformation("Nightly JSON: tìm thấy {Count} CSKCB cần sinh lại.", ids.Count);

                foreach (var idCskcb in ids)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    try
                    {
                        await service.DongBoTatCaJsonTuDbAsync(idCskcb);
                    }
                    catch (Exception ex)
                    {
                        loi.Add($"CSKCB {idCskcb}: {ex.Message}");
                        _logger.LogError(ex, "Nightly JSON lỗi tại CSKCB {IdCskcb}.", idCskcb);
                    }
                }

                string? lastError = loi.Count == 0 ? null : string.Join(" | ", loi);
                await KetThucLichAsync(
                    connection,
                    now,
                    loi.Count == 0 ? "THANH_CONG" : "LOI",
                    lastError,
                    cancellationToken);

                if (loi.Count == 0)
                    _logger.LogInformation("Nightly JSON hoàn tất lúc {Time}.", now);
                else
                    _logger.LogWarning("Nightly JSON hoàn tất có {Count} lỗi; tenant lỗi vẫn dirty để retry.", loi.Count);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nightly JSON worker gặp lỗi khi kiểm tra/chạy lịch.");
            }
            finally
            {
                if (daKhoa)
                {
                    try
                    {
                        await NhaLockDemAsync(connection, cancellationToken);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Không giải phóng được SQL application lock nightly.");
                    }
                }
            }
        }

        private static bool CanChay(LichDongBoRow? lich, DateTime now)
        {
            if (lich == null) return false;

            var today = now.Date;

            // Chưa chạy ngày hôm nay: chạy ngay khi worker phát hiện, kể cả trường hợp
            // app bị recycle và bỏ lỡ 00:00.
            if (!lich.NgayChayCuoi.HasValue)
                return false;

            if (lich.NgayChayCuoi.Value.Date < today)
                return true;

            // Nếu lượt hôm nay lỗi hoặc process chết giữa chừng, retry sau 15 phút.
            if ((string.Equals(lich.TrangThai, "LOI", StringComparison.OrdinalIgnoreCase)
                 || string.Equals(lich.TrangThai, "DANG_CHAY", StringComparison.OrdinalIgnoreCase))
                && lich.LanChayCuoi.HasValue
                && lich.LanChayCuoi.Value <= now.Subtract(RetryInterval))
                return true;

            return false;
        }

        private static async Task<DateTime> LayThoiGianServerSqlAsync(
            System.Data.Common.DbConnection connection, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_LayThoiGian";
            var value = await cmd.ExecuteScalarAsync(cancellationToken);
            return value is DateTime dt ? dt : Convert.ToDateTime(value);
        }

        private static async Task<LichDongBoRow?> LayLichAsync(
            System.Data.Common.DbConnection connection, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_LayLich";
            await using var rd = await cmd.ExecuteReaderAsync(cancellationToken);
            if (!await rd.ReadAsync(cancellationToken)) return null;
            return new LichDongBoRow
            {
                NgayChayCuoi = rd.IsDBNull(0) ? null : rd.GetDateTime(0),
                LanChayCuoi = rd.IsDBNull(1) ? null : rd.GetDateTime(1),
                TrangThai = rd.IsDBNull(2) ? string.Empty : rd.GetString(2)
            };
        }

        private static async Task BatDauLichAsync(
            System.Data.Common.DbConnection connection, DateTime now, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_BatDauLich";
            AddParameter(cmd, "@LanChayCuoi", now);
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }

        private static async Task KetThucLichAsync(
            System.Data.Common.DbConnection connection, DateTime now,
            string trangThai, string? lastError, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_KetThucLich";
            AddParameter(cmd, "@NgayChayCuoi", now.Date);
            AddParameter(cmd, "@LanChayCuoi", now);
            AddParameter(cmd, "@TrangThai", trangThai);
            AddParameter(cmd, "@LastError", (object?)lastError ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }

        private static async Task<bool> ThuLockDemAsync(
            System.Data.Common.DbConnection connection, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_ThuLockDem";
            var result = await cmd.ExecuteScalarAsync(cancellationToken);
            return result != null && Convert.ToInt32(result) >= 0;
        }

        private static async Task NhaLockDemAsync(
            System.Data.Common.DbConnection connection, CancellationToken cancellationToken)
        {
            await using var cmd = connection.CreateCommand();
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandText = "dbo.STO_HT_JSON_NhaLockDem";
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }

        private static void AddParameter(
            System.Data.Common.DbCommand command,
            string name,
            object value)
        {
            var p = command.CreateParameter();
            p.ParameterName = name;
            p.Value = value;
            command.Parameters.Add(p);
        }

        private sealed class LichDongBoRow
        {
            public DateTime? NgayChayCuoi { get; set; }
            public DateTime? LanChayCuoi { get; set; }
            public string TrangThai { get; set; } = string.Empty;
        }
    }
}
