using eBiblioteka.Api.Dtos;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Extensions;

public static class QueryableExtensions
{
    public static async Task<PagedResultDto<T>> ToPagedAsync<T>(this IQueryable<T> query, PagedQueryDto paging)
    {
        var total = await query.CountAsync();
        var items = await query
            .Skip((paging.Page - 1) * paging.PageSize)
            .Take(paging.PageSize)
            .ToListAsync();

        return new PagedResultDto<T>
        {
            Items = items,
            TotalCount = total,
            Page = paging.Page,
            PageSize = paging.PageSize
        };
    }
}
