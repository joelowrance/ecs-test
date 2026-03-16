namespace EcsExample.Api.Endpoints;

internal static class HelloEndpoints
{
    private const string AppVersion = "1.0.0";

    public static IEndpointRouteBuilder MapHelloEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/hello", () =>
            Results.Ok(new HelloResponse(
                Message: "Hello, World!",
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
