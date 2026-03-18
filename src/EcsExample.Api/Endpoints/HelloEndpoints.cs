using System.Reflection;

namespace EcsExample.Api.Endpoints;

internal static class HelloEndpoints
{
    private static readonly string AppVersion =
        typeof(HelloEndpoints).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
            ?.InformationalVersion ?? "unknown";

    public static IEndpointRouteBuilder MapHelloEndpoints(this IEndpointRouteBuilder app)
    {
#pragma warning disable CA1305
        var message = "Hello, World! @" + DateTime.UtcNow.ToString("yyyy-MM-dd HH:m :ss");
#pragma warning restore CA1305

        app.MapGet("/hello", () =>
            Results.Ok(new HelloResponse(
                Message: message,
                Timestamp: DateTimeOffset.UtcNow,
                Version: AppVersion
            )))
            .WithName("GetHello")
            .WithTags("Hello")
            .WithSummary("Returns a hello world greeting")
            .Produces<HelloResponse>();

        return app;
    }
}

/// <summary>
/// Response payload for the /hello endpoint.
/// Using a sealed record gives value equality (useful in tests) and
/// correct JSON serialization with camelCase property names.
/// </summary>
internal sealed record HelloResponse(
    string Message,
    DateTimeOffset Timestamp,
    string Version
);
