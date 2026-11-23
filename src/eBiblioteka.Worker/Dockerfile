# Izgradnja
FROM mcr.microsoft.com/dotnet/sdk:10.0.203 AS build
WORKDIR /src

COPY eBiblioteka.Shared/eBiblioteka.Shared.csproj eBiblioteka.Shared/
COPY eBiblioteka.Worker/eBiblioteka.Worker.csproj eBiblioteka.Worker/
RUN dotnet restore eBiblioteka.Worker/eBiblioteka.Worker.csproj

COPY eBiblioteka.Shared/ eBiblioteka.Shared/
COPY eBiblioteka.Worker/ eBiblioteka.Worker/
RUN dotnet publish eBiblioteka.Worker/eBiblioteka.Worker.csproj -c Release -o /app --no-restore

# Pokretanje
FROM mcr.microsoft.com/dotnet/runtime:10.0.15 AS runtime
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "eBiblioteka.Worker.dll"]
