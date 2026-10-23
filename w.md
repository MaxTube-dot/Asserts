using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace TCB.Realty.Auth.Tests;

public class CoBrokerAuthServiceSecurityTests
{
    private readonly CoBrokerAuthConf _config;
    private readonly CoBrokerAuthService _authService;
    private readonly string _validKeyBase64;
    private readonly SymmetricSecurityKey _validKey;

    public CoBrokerAuthServiceSecurityTests()
    {
        // Генерируем валидный 32-байтный ключ (256 бит) для тестов
        var keyBytes = new byte[32];
        new Random().NextBytes(keyBytes);
        _validKeyBase64 = Convert.ToBase64String(keyBytes);
        _validKey = new SymmetricSecurityKey(keyBytes);

        _config = new CoBrokerAuthConf 
        { 
            SigningKey = _validKeyBase64, 
            TokenLifetime = TimeSpan.FromHours(8) 
        };

        _authService = new CoBrokerAuthService(Options.Create(_config));
    }

    [Fact]
    public async Task GetAuthData_ValidToken_ReturnsInfo()
    {
        // Arrange
        var info = new CoBrokerTokenInfo("app-123");
        var token = await _authService.AuthAsync(info);

        // Act
        var result = await _authService.GetAuthDataAsync(token);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("app-123", result.ApplicationId);
    }

    [Fact]
    public async Task Attack_TamperedSignature_ReturnsNull()
    {
        // Arrange
        var token = await _authService.AuthAsync(new CoBrokerTokenInfo("app-123"));
        // Изменяем последний символ подписи
        var tamperedToken = token.Substring(0, token.Length - 1) + (token.EndsWith("a") ? "b" : "a");

        // Act
        var result = await _authService.GetAuthDataAsync(tamperedToken);

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task Attack_NoneAlgorithm_ReturnsNull()
    {
        // Arrange: имитируем уязвимость Alg="none" (без подписи)
        var header = Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"alg\":\"none\",\"typ\":\"JWT\"}"));
        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"sub\":\"app-123\"}"));
        var token = $"{header}.{payload}."; // Подпись пустая

        // Act
        var result = await _authService.GetAuthDataAsync(token);

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task Attack_SignedWithDifferentKey_ReturnsNull()
    {
        // Arrange: злоумышленник подписал токен своим валидным 256-битным ключом
        var hackerKeyBytes = new byte[32];
        new Random().NextBytes(hackerKeyBytes);
        var hackerKey = new SymmetricSecurityKey(hackerKeyBytes);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity([new Claim(JwtRegisteredClaimNames.Sub, "app-123")]),
            Expires = DateTime.UtcNow.AddHours(1),
            SigningCredentials = new SigningCredentials(hackerKey, SecurityAlgorithms.HmacSha256)
        };

        var handler = new JwtSecurityTokenHandler();
        var hackerToken = handler.WriteToken(handler.CreateToken(tokenDescriptor));

        // Act
        var result = await _authService.GetAuthDataAsync(hackerToken);

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task Attack_ExpiredToken_ReturnsNull()
    {
        // Arrange: токен истек 15 секунд назад (превышает ClockSkew в 10 секунд)
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity([new Claim(JwtRegisteredClaimNames.Sub, "app-123")]),
            Expires = DateTime.UtcNow.Subtract(TimeSpan.FromSeconds(15)),
            SigningCredentials = new SigningCredentials(_validKey, SecurityAlgorithms.HmacSha256)
        };

        var handler = new JwtSecurityTokenHandler();
        var expiredToken = handler.WriteToken(handler.CreateToken(tokenDescriptor));

        // Act
        var result = await _authService.GetAuthDataAsync(expiredToken);

        // Assert
        Assert.Null(result);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Bearer null")]
    [InlineData("just-some-random-string")]
    [InlineData("header.payload")] // Отсутствует часть подписи
    public async Task Attack_MalformedFormat_ReturnsNull(string invalidToken)
    {
        // Act
        var result = await _authService.GetAuthDataAsync(invalidToken);

        // Assert
        Assert.Null(result);
    }
}
