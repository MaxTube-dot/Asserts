using System.Net.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Http.Resilience;
using Polly;
using Polly.Retry;
using Refit;

public static class SessionClientRegistration
{
    public static IServiceCollection AddSessionClient(this IServiceCollection services)
    {
        var refitSettings = new RefitSettings
        {
            ContentSerializer = Json.ContentSerializer,
            ExceptionFactory = CustomRefitExceptionFactory
        };

        services
            .AddRefitClient<ISessionApi>(refitSettings)
            .ConfigureHttpClient((sp, c) =>
            {
                var options = sp.GetRequiredService<IOptions<SessionClientOptions>>().Value;
                c.BaseAddress = new Uri(options.Endpoint);
                c.Timeout = TimeSpan.FromSeconds(options.Timeout);
            })
            .AddResilienceHandler("session-response-ended-retry", static (pipelineBuilder, context) =>
            {
                var loggerFactory = context.ServiceProvider.GetRequiredService<ILoggerFactory>();
                var logger = loggerFactory.CreateLogger("SessionApiRetry");

                var retryOptions = new HttpRetryStrategyOptions
                {
                    MaxRetryAttempts = 2,
                    Delay = TimeSpan.FromMilliseconds(100),
                    BackoffType = DelayBackoffType.Constant,

                    ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                        .Handle<HttpRequestException>(ex =>
                            ex.InnerException is HttpIOException httpIoEx &&
                            httpIoEx.HttpRequestError == HttpRequestError.ResponseEnded),

                    OnRetry = args =>
                    {
                        logger.LogWarning(
                            "Retry #{Attempt} for session API because of ResponseEnded. Next delay: {DelayMs} ms",
                            args.AttemptNumber + 1,
                            args.RetryDelay.TotalMilliseconds);

                        return default;
                    }
                };

                pipelineBuilder.AddRetry(retryOptions);
            })
            .UseTinkoffHttpClientMetrics()
            .UseTcHttpLogging();

        services.AddClient<ISessionClient, SessionClient, ISessionApi>();

        return services;
    }

    // Заглушки для примера
    private static Task<Exception?> CustomRefitExceptionFactory(HttpResponseMessage response)
        => Task.FromResult<Exception?>(null);
}