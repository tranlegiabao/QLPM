namespace QuanLyPhongMach.Services.ToaThuocQuocGia;

public sealed class ToaThuocDeliveryWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ToaThuocDeliveryWorker> _logger;

    public ToaThuocDeliveryWorker(IServiceScopeFactory scopeFactory, ILogger<ToaThuocDeliveryWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var service = scope.ServiceProvider.GetRequiredService<IToaThuocDeliveryService>();
                var processed = await service.XuLyHangDoiAsync(stoppingToken);
                await Task.Delay(processed > 0 ? TimeSpan.FromSeconds(1) : TimeSpan.FromSeconds(10), stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Worker liên thông toa thuốc gặp lỗi.");
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }
    }
}
