using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace EcsExample.Api.Health;

/// <summary>
/// Readiness health check. In a real application this would verify
/// database connectivity, downstream service reachability, cache availability, etc.
/// For this reference app it always reports healthy — extend as needed.
/// </summary>
internal sealed class ReadinessHealthCheck : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        // TODO: add real dependency checks (database, external services, etc.)
        return Task.FromResult(
            HealthCheckResult.Healthy("All dependencies are reachable."));
    }
}
