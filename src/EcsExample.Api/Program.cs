using EcsExample.Api.Endpoints;
using EcsExample.Api.Health;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Scalar.AspNetCore;
using Serilog;
using System.Globalization;
using System.Text.Json;

// Bootstrap logger catches startup failures before the full pipeline is configured.
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture)
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // ------------------------------------------------------------------ //
    // Logging — Serilog reads full config from appsettings.json           //
    // ------------------------------------------------------------------ //
    builder.Host.UseSerilog((context, services, configuration) =>
        configuration
            .ReadFrom.Configuration(context.Configuration)
            .ReadFrom.Services(services)
            .Enrich.FromLogContext()
            .Enrich.WithProperty("Application", "EcsExample.Api")
            .Enrich.WithProperty("Environment", context.HostingEnvironment.EnvironmentName));

    // ------------------------------------------------------------------ //
    // OpenAPI — development only                                           //
    // ------------------------------------------------------------------ //
    if (builder.Environment.IsDevelopment())
    {
        builder.Services.AddOpenApi();
    }

    // ------------------------------------------------------------------ //
    // Health checks                                                        //
    // /health       → liveness  (no dependency checks, used by ALB)       //
    // /health/ready → readiness (checks real dependencies)                 //
    // ------------------------------------------------------------------ //
    builder.Services.AddHealthChecks()
        .AddCheck<ReadinessHealthCheck>("readiness");

    // ------------------------------------------------------------------ //
    // Build                                                                //
    // ------------------------------------------------------------------ //
    var app = builder.Build();

    // Structured request logging — replaces the default ASP.NET Core middleware logs.
    app.UseSerilogRequestLogging(options =>
    {
        options.MessageTemplate =
            "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms";
    });

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
        // Scalar UI at /scalar — modern replacement for Swagger UI
        app.MapScalarApiReference(options =>
        {
            options.Title = "ECS Example API";
            options.Theme = ScalarTheme.Default;
        });
    }

    // ------------------------------------------------------------------ //
    // Endpoints                                                            //
    // ------------------------------------------------------------------ //
    app.MapHelloEndpoints();

    // Liveness: no dependency checks, just confirms the HTTP stack is alive.
    // The ALB health check targets this path.
    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        Predicate = _ => false,
        ResultStatusCodes =
        {
            [HealthStatus.Healthy] = StatusCodes.Status200OK,
        }
    });

    // Readiness: runs registered health checks and returns structured JSON.
    app.MapHealthChecks("/health/ready", new HealthCheckOptions
    {
        Predicate = check => check.Name == "readiness",
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "application/json";
            var result = JsonSerializer.Serialize(new
            {
                status = report.Status.ToString(),
                checks = report.Entries.Select(e => new
                {
                    name = e.Key,
                    status = e.Value.Status.ToString(),
                    description = e.Value.Description,
                })
            });
            await context.Response.WriteAsync(result).ConfigureAwait(false);
        }
    });

    await app.RunAsync().ConfigureAwait(false);
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    // HostAbortedException is thrown intentionally by EF Core migration host;
    // filtering it prevents a false "fatal" log entry on normal termination.
    Log.Fatal(ex, "Application terminated unexpectedly");
    throw;
}
finally
{
    await Log.CloseAndFlushAsync().ConfigureAwait(false);
}
