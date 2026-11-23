using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Middleware;

public class ExceptionHandlingMiddleware
{
    private const int SqlForeignKeyViolation = 547;
    private const int SqlUniqueIndexViolation = 2601;
    private const int SqlUniqueConstraintViolation = 2627;

    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception ex)
    {
        var (status, message) = ex switch
        {
            BadRequestException => (StatusCodes.Status400BadRequest, ex.Message),
            UnauthorizedException => (StatusCodes.Status401Unauthorized, ex.Message),
            ForbiddenException => (StatusCodes.Status403Forbidden, ex.Message),
            NotFoundException => (StatusCodes.Status404NotFound, ex.Message),
            ConflictException => (StatusCodes.Status409Conflict, ex.Message),
            DbUpdateException { InnerException: SqlException sql } when IsConstraintViolation(sql) =>
                (StatusCodes.Status409Conflict, "Radnja nije dozvoljena jer krši pravila integriteta podataka (zapis se koristi ili već postoji)."),
            _ => (StatusCodes.Status500InternalServerError, "Došlo je do greške na serveru.")
        };

        if (status == StatusCodes.Status500InternalServerError)
        {
            _logger.LogError(ex, "Neobrađena greška pri obradi zahtjeva {Method} {Path}",
                context.Request.Method, context.Request.Path);
        }

        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new ErrorResponseDto
        {
            Status = status,
            Message = message
        });
    }

    private static bool IsConstraintViolation(SqlException sql) =>
        sql.Number is SqlForeignKeyViolation or SqlUniqueIndexViolation or SqlUniqueConstraintViolation;
}
