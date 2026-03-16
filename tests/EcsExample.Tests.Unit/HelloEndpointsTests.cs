namespace EcsExample.Tests.Unit;

public sealed class HelloResponseTests
{
    [Fact]
    public void HelloResponse_HasExpectedMessage()
    {
        var timestamp = DateTimeOffset.UtcNow;
        var response = new HelloResponse("Hello, World!", timestamp, "1.0.0");

        response.Message.Should().Be("Hello, World!");
    }

    [Fact]
    public void HelloResponse_HasExpectedVersion()
    {
        var response = new HelloResponse("Hello, World!", DateTimeOffset.UtcNow, "1.0.0");

        response.Version.Should().Be("1.0.0");
    }

    [Fact]
    public void HelloResponse_TimestampIsUtc()
    {
        var before = DateTimeOffset.UtcNow;
        var response = new HelloResponse("Hello, World!", DateTimeOffset.UtcNow, "1.0.0");
        var after = DateTimeOffset.UtcNow;

        response.Timestamp.Should().BeOnOrAfter(before).And.BeOnOrBefore(after);
    }

    [Fact]
    public void HelloResponse_ValueEquality_WorksCorrectly()
    {
        var ts = DateTimeOffset.UtcNow;
        var a = new HelloResponse("Hello, World!", ts, "1.0.0");
        var b = new HelloResponse("Hello, World!", ts, "1.0.0");

        // Records provide structural equality — important for assertion correctness in tests.
        a.Should().Be(b);
    }
}
