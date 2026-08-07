Да. Для режима миграции я бы сделал адаптер максимально простым:
	•	Get / GetAsync → только старый Redis;
	•	Set / SetAsync → оба Redis;
	•	Remove / RemoveAsync → оба Redis;
	•	Refresh / RefreshAsync → оба Redis.

Последние два пункта важны: если вы удалили ключ или продлили sliding expiration только в старом Redis, после переключения можете получить устаревшие данные или неожиданно истёкшие записи.

Keyed services есть в DI начиная с .NET 8, поэтому ими удобно различать два IDistributedCache.  ￼

Сам адаптер:

using Microsoft.Extensions.Caching.Distributed;

public sealed class DualWriteDistributedCache : IDistributedCache
{
    private readonly IDistributedCache _oldCache;
    private readonly IDistributedCache _newCache;

    public DualWriteDistributedCache(
        IDistributedCache oldCache,
        IDistributedCache newCache)
    {
        _oldCache = oldCache;
        _newCache = newCache;
    }

    public byte[]? Get(string key)
    {
        return _oldCache.Get(key);
    }

    public Task<byte[]?> GetAsync(
        string key,
        CancellationToken token = default)
    {
        return _oldCache.GetAsync(key, token);
    }

    public void Set(
        string key,
        byte[] value,
        DistributedCacheEntryOptions options)
    {
        _oldCache.Set(key, value, options);
        _newCache.Set(key, value, options);
    }

    public async Task SetAsync(
        string key,
        byte[] value,
        DistributedCacheEntryOptions options,
        CancellationToken token = default)
    {
        await Task.WhenAll(
            _oldCache.SetAsync(key, value, options, token),
            _newCache.SetAsync(key, value, options, token));
    }

    public void Remove(string key)
    {
        _oldCache.Remove(key);
        _newCache.Remove(key);
    }

    public async Task RemoveAsync(
        string key,
        CancellationToken token = default)
    {
        await Task.WhenAll(
            _oldCache.RemoveAsync(key, token),
            _newCache.RemoveAsync(key, token));
    }

    public void Refresh(string key)
    {
        _oldCache.Refresh(key);
        _newCache.Refresh(key);
    }

    public async Task RefreshAsync(
        string key,
        CancellationToken token = default)
    {
        await Task.WhenAll(
            _oldCache.RefreshAsync(key, token),
            _newCache.RefreshAsync(key, token));
    }
}

На первом этапе я бы именно так и оставил обработку ошибок: если запись в новый Redis упала, операция тоже падает. Это позволяет не скрыть ситуацию, когда новый Redis фактически не прогревается. Позже можно добавить более сложную fail-open политику.

Для регистрации сначала заведём ключи:

public static class CacheServiceKeys
{
    public const string Old = "old";
    public const string New = "new";
}

RedisCache принимает IOptions<RedisCacheOptions>, а RedisCacheOptions содержит Configuration/ConfigurationOptions и InstanceName.  ￼

Поэтому Program.cs может выглядеть так:

using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddKeyedSingleton<IDistributedCache>(
    CacheServiceKeys.Old,
    (_, _) =>
    {
        var options = Options.Create(new RedisCacheOptions
        {
            Configuration = builder.Configuration
                .GetConnectionString("RedisOld"),

            InstanceName = "my-app:"
        });

        return new RedisCache(options);
    });

builder.Services.AddKeyedSingleton<IDistributedCache>(
    CacheServiceKeys.New,
    (_, _) =>
    {
        var options = Options.Create(new RedisCacheOptions
        {
            Configuration = builder.Configuration
                .GetConnectionString("RedisNew"),

            InstanceName = "my-app:"
        });

        return new RedisCache(options);
    });

builder.Services.AddSingleton<IDistributedCache>(serviceProvider =>
{
    var oldCache =
        serviceProvider.GetRequiredKeyedService<IDistributedCache>(
            CacheServiceKeys.Old);

    var newCache =
        serviceProvider.GetRequiredKeyedService<IDistributedCache>(
            CacheServiceKeys.New);

    return new DualWriteDistributedCache(
        oldCache,
        newCache);
});

И конфигурация:

{
  "ConnectionStrings": {
    "RedisOld": "redis-old:6379",
    "RedisNew": "redis-new:6379"
  }
}

Обычный application code при этом вообще не меняется:

public sealed class UserService
{
    private readonly IDistributedCache _cache;

    public UserService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public Task<byte[]?> GetUserAsync(
        string userId,
        CancellationToken cancellationToken)
    {
        return _cache.GetAsync(
            $"user:{userId}",
            cancellationToken);
    }
}

UserService получает обычный IDistributedCache, но фактически DI выдаёт DualWriteDistributedCache.

Для unit-тестов я бы не поднимал Redis. Здесь нужно тестировать именно маршрутизацию вызовов, поэтому достаточно моков IDistributedCache. Например, xUnit + NSubstitute.

Пакеты:

<ItemGroup>
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="*" />
  <PackageReference Include="xunit" Version="*" />
  <PackageReference Include="xunit.runner.visualstudio" Version="*" />
  <PackageReference Include="NSubstitute" Version="*" />
</ItemGroup>

Тест чтения — ключевой сценарий: читать должны исключительно из старого.

using Microsoft.Extensions.Caching.Distributed;
using NSubstitute;

public sealed class DualWriteDistributedCacheTests
{
    [Fact]
    public async Task GetAsync_Reads_From_Old_Cache_Only()
    {
        // Arrange
        var oldCache = Substitute.For<IDistributedCache>();
        var newCache = Substitute.For<IDistributedCache>();

        var expected = new byte[] { 1, 2, 3 };

        oldCache
            .GetAsync(
                "key",
                Arg.Any<CancellationToken>())
            .Returns(expected);

        var sut = new DualWriteDistributedCache(
            oldCache,
            newCache);

        // Act
        var result = await sut.GetAsync("key");

        // Assert
        Assert.Equal(expected, result);

        await oldCache.Received(1)
            .GetAsync(
                "key",
                Arg.Any<CancellationToken>());

        await newCache.DidNotReceive()
            .GetAsync(
                Arg.Any<string>(),
                Arg.Any<CancellationToken>());
    }
}

Тест SetAsync проверяет, что одна запись ушла в оба Redis:

[Fact]
public async Task SetAsync_Writes_To_Both_Caches()
{
    // Arrange
    var oldCache = Substitute.For<IDistributedCache>();
    var newCache = Substitute.For<IDistributedCache>();

    var sut = new DualWriteDistributedCache(
        oldCache,
        newCache);

    var value = new byte[] { 1, 2, 3 };

    var options = new DistributedCacheEntryOptions
    {
        AbsoluteExpirationRelativeToNow =
            TimeSpan.FromHours(2)
    };

    // Act
    await sut.SetAsync(
        "key",
        value,
        options);

    // Assert
    await oldCache.Received(1)
        .SetAsync(
            "key",
            value,
            options,
            Arg.Any<CancellationToken>());

    await newCache.Received(1)
        .SetAsync(
            "key",
            value,
            options,
            Arg.Any<CancellationToken>());
}

Удаление тоже должно идти в оба:

[Fact]
public async Task RemoveAsync_Removes_From_Both_Caches()
{
    // Arrange
    var oldCache = Substitute.For<IDistributedCache>();
    var newCache = Substitute.For<IDistributedCache>();

    var sut = new DualWriteDistributedCache(
        oldCache,
        newCache);

    // Act
    await sut.RemoveAsync("key");

    // Assert
    await oldCache.Received(1)
        .RemoveAsync(
            "key",
            Arg.Any<CancellationToken>());

    await newCache.Received(1)
        .RemoveAsync(
            "key",
            Arg.Any<CancellationToken>());
}

И RefreshAsync:

[Fact]
public async Task RefreshAsync_Refreshes_Both_Caches()
{
    // Arrange
    var oldCache = Substitute.For<IDistributedCache>();
    var newCache = Substitute.For<IDistributedCache>();

    var sut = new DualWriteDistributedCache(
        oldCache,
        newCache);

    // Act
    await sut.RefreshAsync("key");

    // Assert
    await oldCache.Received(1)
        .RefreshAsync(
            "key",
            Arg.Any<CancellationToken>());

    await newCache.Received(1)
        .RefreshAsync(
            "key",
            Arg.Any<CancellationToken>());
}

Ещё один полезный тест — если ключа нет в старом Redis, адаптер не должен пытаться читать новый. Это принципиально для выбранной вами схемы миграции:

[Fact]
public async Task GetAsync_When_Old_Cache_Misses_Does_Not_Read_New_Cache()
{
    // Arrange
    var oldCache = Substitute.For<IDistributedCache>();
    var newCache = Substitute.For<IDistributedCache>();

    oldCache
        .GetAsync(
            "missing-key",
            Arg.Any<CancellationToken>())
        .Returns((byte[]?)null);

    var sut = new DualWriteDistributedCache(
        oldCache,
        newCache);

    // Act
    var result = await sut.GetAsync("missing-key");

    // Assert
    Assert.Null(result);

    await oldCache.Received(1)
        .GetAsync(
            "missing-key",
            Arg.Any<CancellationToken>());

    await newCache.DidNotReceive()
        .GetAsync(
            Arg.Any<string>(),
            Arg.Any<CancellationToken>());
}

Я бы протестировал ещё и саму DI-регистрацию. Это ловит неприятную ошибку, когда обычный IDistributedCache случайно начинает резолвиться как один из Redis вместо адаптера.

Например:

[Fact]
public void Di_Resolves_DualWriteDistributedCache_As_Default_Cache()
{
    var services = new ServiceCollection();

    var oldCache = Substitute.For<IDistributedCache>();
    var newCache = Substitute.For<IDistributedCache>();

    services.AddKeyedSingleton<IDistributedCache>(
        CacheServiceKeys.Old,
        oldCache);

    services.AddKeyedSingleton<IDistributedCache>(
        CacheServiceKeys.New,
        newCache);

    services.AddSingleton<IDistributedCache>(sp =>
        new DualWriteDistributedCache(
            sp.GetRequiredKeyedService<IDistributedCache>(
                CacheServiceKeys.Old),

            sp.GetRequiredKeyedService<IDistributedCache>(
                CacheServiceKeys.New)));

    using var provider = services.BuildServiceProvider();

    var cache =
        provider.GetRequiredService<IDistributedCache>();

    Assert.IsType<DualWriteDistributedCache>(cache);
}

Таким образом архитектура получается такой:

                       ┌───────────────┐
Application ──────────►│IDistributedCache│
                       └───────┬───────┘
                               │
                               ▼
                    DualWriteDistributedCache
                       │                │
              READ ────┘                │
                       │                │
                       ▼                ▼
                  OLD Redis         NEW Redis
                     ▲                  ▲
                     └──── WRITE ───────┘

Через 2 часа плюс запас вы меняете только стратегию адаптера на read NEW / write OLD+NEW, а application layer вообще не трогаете.

Есть ещё один архитектурный момент, который я бы изменил относительно этого минимального примера: вместо строковых keyed services сделать отдельные типы OldCache / NewCache или маленькие интерфейсы-маркеры. Это делает DI более типобезопасным и особенно удобно в тестах. Для production-кода с последующим переключением между фазами миграции такой вариант обычно получается чище.