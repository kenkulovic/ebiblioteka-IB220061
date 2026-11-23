# Izgradnja
FROM mcr.microsoft.com/dotnet/sdk:10.0.203 AS build
WORKDIR /src

# Prvo samo .csproj fajlovi, da se restore keširа dok se paketi ne promijene.
COPY eBiblioteka.Shared/eBiblioteka.Shared.csproj eBiblioteka.Shared/
COPY eBiblioteka.Api/eBiblioteka.Api.csproj eBiblioteka.Api/
RUN dotnet restore eBiblioteka.Api/eBiblioteka.Api.csproj

COPY eBiblioteka.Shared/ eBiblioteka.Shared/
COPY eBiblioteka.Api/ eBiblioteka.Api/
RUN dotnet publish eBiblioteka.Api/eBiblioteka.Api.csproj -c Release -o /app --no-restore

# Pokretanje
FROM mcr.microsoft.com/dotnet/aspnet:10.0.15 AS runtime

# QuestPDF treba fontconfig za izradu PDF izvještaja.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "eBiblioteka.Api.dll"]
