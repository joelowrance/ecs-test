# =============================================================
# Stage 1: Restore + Build
# =============================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file first to leverage Docker layer caching for package restore.
# If only source files change, this layer is reused.
COPY ["src/EcsExample.Api/EcsExample.Api.csproj", "EcsExample.Api/"]
RUN dotnet restore "EcsExample.Api/EcsExample.Api.csproj"

# Copy remaining source and build
COPY src/ .
RUN dotnet build "EcsExample.Api/EcsExample.Api.csproj" \
    --configuration Release \
    --no-restore \
    --output /app/build

# =============================================================
# Stage 2: Publish
# =============================================================
FROM build AS publish
RUN dotnet publish "EcsExample.Api/EcsExample.Api.csproj" \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

# =============================================================
# Stage 3: Runtime image
# =============================================================
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Create a non-root system user and group.
# Running as root inside a container is a security anti-pattern.
RUN addgroup --system appgroup \
 && adduser --system --ingroup appgroup --no-create-home appuser

# Copy the published output from the publish stage
COPY --from=publish /app/publish .

# Switch to non-root user before running the application
USER appuser

# Tell ASP.NET Core to listen on port 8080 (non-privileged port, safe for non-root)
ENV ASPNETCORE_HTTP_PORTS=8080

EXPOSE 8080

# Container-level health check.
# Uses wget (pre-installed in the aspnet image) to probe the liveness endpoint.
# --interval:     time between checks (after start-period)
# --timeout:      time to wait for a response
# --start-period: grace period while the app is starting up
# --retries:      consecutive failures to declare the container unhealthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "EcsExample.Api.dll"]
