using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Http.Resilience;
using Microsoft.Extensions.Logging;
using Polly;

namespace YourNamespace.Http;

public static class SessionResponseEndedRetryHandler
{
    public static IHttpClientBuilder AddSessionResponseEndedRetry(
        this IHttpClientBuilder builder)
    {
        builder.AddResilienceHandler(
            "session-response-ended-retry",
            static (pipelineBuilder, context) =>
            {
                var loggerFactory =
                    context.ServiceProvider.GetRequiredService<ILoggerFactory>();

                var logger =
                    loggerFactory.CreateLogger("SessionApiRetry");

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
                            "Retry #{Attempt} because of ResponseEnded. Next delay: {DelayMs} ms",
                            args.AttemptNumber + 1,
                            args.RetryDelay.TotalMilliseconds);

                        return default;
                    }
                };

                pipelineBuilder.AddRetry(retryOptions);
            });

        return builder;
    }
}