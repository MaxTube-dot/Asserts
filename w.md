Ниже готовый тест-класс для DualWriteDistributedCache на xUnit + NSubstitute.

using Microsoft.Extensions.Caching.Distributed;
using NSubstitute;
using Xunit;

public sealed class DualWriteDistributedCacheTests
{
    private readonly IDistributedCache _oldCache;
    private readonly IDistributedCache _newCache;
    private readonly DualWriteDistributedCache _sut;

    public DualWriteDistributedCacheTests()
    {
        _oldCache = Substitute.For<IDistributedCache>();
        _newCache = Substitute.For<IDistributedCache>();

        _sut = new DualWriteDistributedCache(
            _oldCache,
            _newCache);
    }

    [Fact]
    public async Task GetAsync_Should_Read_From_Old_Cache_Only()
    {
        // Arrange
        var key = "test-key";
        var expected = new byte[] { 1, 2, 3 };

        _oldCache
            .GetAsync(key, Arg.Any<CancellationToken>())
            .Returns(expected);

        // Act
        var result = await _sut.GetAsync(key);

        // Assert
        Assert.Equal(expected, result);

        await _oldCache.Received(1)
            .GetAsync(
                key,
                Arg.Any<CancellationToken>());

        await _newCache.DidNotReceive()
            .GetAsync(
                Arg.Any<string>(),
                Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task GetAsync_When_Key_Does_Not_Exist_Should_Not_Read_From_New_Cache()
    {
        // Arrange
        var key = "missing-key";

        _oldCache
            .GetAsync(key, Arg.Any<CancellationToken>())
            .Returns((byte[]?)null);

        // Act
        var result = await _sut.GetAsync(key);

        // Assert
        Assert.Null(result);

        await _oldCache.Received(1)
            .GetAsync(
                key,
                Arg.Any<CancellationToken>());

        await _newCache.DidNotReceive()
            .GetAsync(
                Arg.Any<string>(),
                Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SetAsync_Should_Write_To_Both_Caches()
    {
        // Arrange
        var key = "test-key";
        var value = new byte[] { 1, 2, 3 };

        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(2)
        };

        // Act
        await _sut.SetAsync(
            key,
            value,
            options);

        // Assert
        await _oldCache.Received(1)
            .SetAsync(
                key,
                value,
                options,
                Arg.Any<CancellationToken>());

        await _newCache.Received(1)
            .SetAsync(
                key,
                value,
                options,
                Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task RemoveAsync_Should_Remove_From_Both_Caches()
    {
        // Arrange
        var key = "test-key";

        // Act
        await _sut.RemoveAsync(key);

        // Assert
        await _oldCache.Received(1)
            .RemoveAsync(
                key,
                Arg.Any<CancellationToken>());

        await _newCache.Received(1)
            .RemoveAsync(
                key,
                Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task RefreshAsync_Should_Refresh_Both_Caches()
    {
        // Arrange
        var key = "test-key";

        // Act
        await _sut.RefreshAsync(key);

        // Assert
        await _oldCache.Received(1)
            .RefreshAsync(
                key,
                Arg.Any<CancellationToken>());

        await _newCache.Received(1)
            .RefreshAsync(
                key,
                Arg.Any<CancellationToken>());
    }

    [Fact]
    public void Get_Should_Read_From_Old_Cache_Only()
    {
        // Arrange
        var key = "test-key";
        var expected = new byte[] { 10, 20, 30 };

        _oldCache
            .Get(key)
            .Returns(expected);

        // Act
        var result = _sut.Get(key);

        // Assert
        Assert.Equal(expected, result);

        _oldCache.Received(1)
            .Get(key);

        _newCache.DidNotReceive()
            .Get(Arg.Any<string>());
    }

    [Fact]
    public void Set_Should_Write_To_Both_Caches()
    {
        // Arrange
        var key = "test-key";
        var value = new byte[] { 1, 2, 3 };

        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(2)
        };

        // Act
        _sut.Set(
            key,
            value,
            options);

        // Assert
        _oldCache.Received(1)
            .Set(
                key,
                value,
                options);

        _newCache.Received(1)
            .Set(
                key,
                value,
                options);
    }

    [Fact]
    public void Remove_Should_Remove_From_Both_Caches()
    {
        // Arrange
        var key = "test-key";

        // Act
        _sut.Remove(key);

        // Assert
        _oldCache.Received(1)
            .Remove(key);

        _newCache.Received(1)
            .Remove(key);
    }

    [Fact]
    public void Refresh_Should_Refresh_Both_Caches()
    {
        // Arrange
        var key = "test-key";

        // Act
        _sut.Refresh(key);

        // Assert
        _oldCache.Received(1)
            .Refresh(key);

        _newCache.Received(1)
            .Refresh(key);
    }
}

Этот класс предполагает, что адаптер выглядит примерно так:

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
        => _oldCache.Get(key);

    public Task<byte[]?> GetAsync(
        string key,
        CancellationToken token = default)
        => _oldCache.GetAsync(key, token);

    public void Set(
        string key,
        byte[] value,
        DistributedCacheEntryOptions options)
    {
        _oldCache.Set(key, value, options);
        _newCache.Set(key, value, options);
    }

    public Task SetAsync(
        string key,
        byte[] value,
        DistributedCacheEntryOptions options,
        CancellationToken token = default)
    {
        return Task.WhenAll(
            _oldCache.SetAsync(key, value, options, token),
            _newCache.SetAsync(key, value, options, token));
    }

    public void Remove(string key)
    {
        _oldCache.Remove(key);
        _newCache.Remove(key);
    }

    public Task RemoveAsync(
        string key,
        CancellationToken token = default)
    {
        return Task.WhenAll(
            _oldCache.RemoveAsync(key, token),
            _newCache.RemoveAsync(key, token));
    }

    public void Refresh(string key)
    {
        _oldCache.Refresh(key);
        _newCache.Refresh(key);
    }

    public Task RefreshAsync(
        string key,
        CancellationToken token = default)
    {
        return Task.WhenAll(
            _oldCache.RefreshAsync(key, token),
            _newCache.RefreshAsync(key, token));
    }
}

И пакеты для тестового проекта:

<ItemGroup>
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
  <PackageReference Include="xunit" Version="2.9.3" />
  <PackageReference Include="xunit.runner.visualstudio" Version="3.1.1" />
  <PackageReference Include="NSubstitute" Version="5.3.0" />
</ItemGroup>

Я бы ещё добавил отдельный тест на DI-регистрацию keyed "old" / "new", потому что именно там наиболее легко случайно перепутать два Redis.