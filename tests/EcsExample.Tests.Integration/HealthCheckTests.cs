namespace EcsExample.Tests.Integration;

public sealed class HealthCheckTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Liveness_ReturnsOk()
    {
        var response = await _client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Readiness_ReturnsOk_WhenHealthy()
    {
        var response = await _client.GetAsync(new Uri("/health/ready", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Readiness_ReturnsJson_WithHealthyStatus()
    {
        var response = await _client.GetAsync(new Uri("/health/ready", UriKind.Relative), TestContext.Current.CancellationToken);
        var content = await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken);

        content.Should().Contain("\"status\":\"Healthy\"");
    }

    [Fact]
    public async Task Hello_ReturnsOk_WithExpectedPayload()
    {
        var response = await _client.GetAsync(new Uri("/hello", UriKind.Relative), TestContext.Current.CancellationToken);
        var content = await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        content.Should().Contain("Hello, World!");
        content.Should().Contain("\"version\":\"1.0.0");
    }
}
